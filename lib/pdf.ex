defmodule PDF do
  @moduledoc ~S"""
  Turns HTML into PDF.
  """

  @typedoc ~S"""
  Allowed inputs to turn into a pdf.

    * `{:file, filename}`, will read the html from the given file.
    * `{:html, html}`, will convert the given html to a PDF.
    * `html`, will be turned into `{:html, html}`.
  """
  @type input :: {:file, String.t} | {:html, String.t} | String.t

  # Base exif to run to clean up.
  @exif_base ~w(-overwrite_original -all:all=)

  # Allowed options per tool.
  @exif_options ~W(author keywords subject title)a
  @qpdf_options ~W(password edit_password modify print)a
  @wkhtmltopdf_options ~W(dpi margin orientation
                          page_height page_size page_width)a

  ### Interface ###

  @doc ~S"""
  Turns the given input into a PDF binary.

  Returns `{:ok, binary}` on success; otherwise returns `{:error, reason}`.

  For options see: `PDF.to_file/2`.
  """
  @spec to_binary(input, Keyword.t) :: {:ok, binary} | {:error, atom}
  def to_binary(data, options \\ []) do
    result =
      with {:ok, file} <- to_file(data, Keyword.delete(options, :output)),
          {:ok, binary} <- File.read(file)
      do
        {:ok, binary}
      end

    Temp.cleanup :pdf_result

    result
  end

  @doc ~S"""
  Turns the given input into a PDF binary.

  Returns `{:ok, filename}` on success; otherwise returns `{:error, reason}`.

  The following options can be passed to customize file creation:

    * `:author`, sets the author of the PDF.
    * `:dpi`, sets the DPI at which the PDF is rendered.
    * `:edit_password`, sets the password protection needed to edit the PDF. (Default: off)
    * `:keywords`, sets the keywords for the PDF.
    * `:margin`, sets the margins for the PDF. Can be given as number or keyword/map with `:top`, `:bottom`, `:left`, `:right`. Not all values have to be given.
    * `:modify`, sets the allowed level of modifications. Options: `:all`, `:annotate`, `:form`, `:assembly`, `:none`. (Default: `:annotate`)
    * `:orientation`, sets the orientation. Options: `:portrait`, `:landscape`.
    * `:page_height`, sets the height of the page. (For example: `"297mm"`.)
    * `:page_size`, sets the size of the page. (For example: `:A4`.)
    * `:page_width`, sets the width of the page. (For example: `"297mm"`.).
    * `:password`, sets the password needed to view the PDF. (Default: off)
    * `:print`, sets the allowed level of printing. Options: `:full`, `:low`, `:none`. (Default: `:full`)
    * `:subject`, sets the subject of the PDF.
    * `:title`, sets the title of the PDF.

  """
  @spec to_file(input, Keyword.t) :: {:ok, String.t} | {:error, atom}
  def to_file(data, options \\ [])

  def to_file({:file, file}, options) do
    result =
      with {:ok, pdf} <- Temp.file(suffix: ".pdf", label: :pdf),
          :ok <- wkhtmltopdf(file, pdf, options),
          :ok <- exif(pdf, options),
          {:ok, pdf_encrypted} <- qpdf(pdf, options)
      do
        {:ok, pdf_encrypted}
      end

    Temp.cleanup :pdf

    result
  end

  def to_file({:html, html}, options) do
    with {:ok, file} <- Temp.file(suffix: ".html", label: :pdf),
         :ok <- File.write(file, html)
    do
      to_file({:file, file}, options)
    end
  end

  def to_file(html, options), do: to_file({:html, html}, options)

  ### Banged! ###

  @doc ~S"""
  Turns the given input into a PDF binary.

  Returns the binary data on success; otherwise returns raises a `RuntimeError`.

  For options see: `PDF.to_file/2`.
  """
  @spec to_binary!(input, Keyword.t) :: binary
  def to_binary!(data, options \\ []) do
    case to_binary(data, options) do
      {:ok, binary} -> binary
      {:error, reason} -> raise RuntimeError, to_string(reason)
    end
  end

  @doc ~S"""
  Turns the given input into a PDF.

  Returns the filename on success; otherwise returns raises a `RuntimeError`.

  For options see: `PDF.to_file/2`.
  """
  @spec to_file!(input, Keyword.t) :: String.t
  def to_file!(data, options \\ []) do
    case to_file(data, options) do
      {:ok, filename} -> filename
      {:error, reason} -> raise RuntimeError, to_string(reason)
    end
  end

  ### Helpers ###

  @spec wkhtmltopdf(String.t, String.t, Keyword.t) :: :ok | {:error, atom}
  defp wkhtmltopdf(from, to, options) do
    args =
      options
      |> parse_options(@wkhtmltopdf_options, &wk_options/1)

    run("wkhtmltopdf", args ++ [from, to])
  end

  @spec exif(String.t, Keyword.t) :: :ok | {:error, atom}
  defp exif(pdf, options) do
    args =
      options
      |> parse_options(@exif_options, &exif_options/1, ["-overwrite_original"])

    with :ok <- run("exiftool", @exif_base ++ [pdf]),
         :ok <- run("exiftool", args ++ [pdf])
    do
      :ok
    end
  end

  @spec qpdf(String.t, Keyword.t) :: :ok | {:error, atom}
  defp qpdf(pdf, options) do
    security_options = Keyword.take(options, @qpdf_options)

    security =
      if security_options != [] do
        [
          "--encrypt",
          security_options[:password] || "",
          security_options[:edit_password] || "",
          "256", # TODO: Add support for 40 and 128
          "--modify=#{security_options[:modify] || :annotate}",
          "--print=#{security_options[:print] || :full}",
          "--"
        ]
      else
        []
      end

    args = ["--linearize" | security]

    with {:ok, file} <- output_file(options),
        :ok <- run("qpdf", args ++ [pdf, file])
    do
      {:ok, file}
    end
  end

  @spec output_file(Keyword.t) :: {:ok, String.t} | {:error, atom}
  defp output_file(options) do
    case options[:output] do
      nil -> Temp.file(suffix: ".pdf", label: :pdf_result)
      file -> {:ok, file}
    end
  end

  @spec run(String.t, [String.t]) :: :ok | {:error, atom}
  defp run(command, args) do
    case System.cmd(command, args, stderr_to_stdout: true) do
      {_, 0} -> :ok
      {_output, _exit_status} ->
        # IO.puts output
        {:error, String.to_atom("invalid_" <> command)}
    end
  end

  @spec parse_options(Keyword.t, [atom], fun, [String.t]) :: [String.t]
  defp parse_options(options, keys, parse, base \\ []) do
    base ++
      (
        options
        |> Keyword.take(keys)
        |> Enum.map(parse)
        |> List.flatten
      )
  end

  @spec exif_options({atom, term}) :: String.t | [String.t]
  defp exif_options({:author, author}), do: "-Author=" <> author
  defp exif_options({:keywords, keywords}),
    do: "-keywords=" <> Enum.join(keywords, " ")
  defp exif_options({:subject, subject}), do: "-Subject=" <> subject
  defp exif_options({:title, title}), do: "-Title=" <> title

  @spec wk_options({atom, term}) :: String.t | [String.t]
  defp wk_options({:dpi, dpi}), do: ["--dpi", to_string(dpi)]
  defp wk_options({:margin, margin}) do
    cond do
      is_integer(margin) ->
        margin = to_string(margin)
        ["-T", margin, "-R", margin, "-B", margin, "-L", margin]
      is_map(margin) or Keyword.keyword?(margin) ->
        margin
        |> Enum.map(fn {key, value} -> ["--margin-#{key}", to_string(value)] end)
        |> List.flatten
      is_list(margin) ->
        [~w(-T -R -B -L), margin]
        |> List.zip
        |> Enum.map(&Tuple.to_list/1)
        |> List.flatten
    end
  end
  defp wk_options({:orientation, orientation}), do: ["--orientation", to_string(orientation)]
  defp wk_options({:page_height, height}), do: ["--page-height", to_string(height)]
  defp wk_options({:page_size, size}), do: ["--page-size", to_string(size)]
  defp wk_options({:page_width, width}), do: ["--page-width", to_string(width)]
end
