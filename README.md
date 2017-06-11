# PDF

Generate [secure] PDF documents with Elixir.

## Installation

The package can be installed by
adding `pdf` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:pdf, "~> 0.1", git: "https://github.com/IanLuites/elixir-pdf.git"}]
end
```

## Use

```elixir
iex> PDF.to_file("<html><p>x</p></html>", author: "Bob", keywords: ~w(shopping store), dpi: 1600)
{:ok, "tmp/AAVRsgST4ds4NjQ4NavJUzrPrLGitZo=.pdf"}

iex> PDF.to_file({:file, input_file}, output: "test.pdf")
{:ok, "test.pdf"}

iex> PDF.to_binary({:url, "https://www.google.nl/"})
{:ok,
 <<37, 80, 68, 70, 45, 49, 46, 52, 10, 37, 191, 247, 162, 254, 10, 52, 32, 48,
   32, 111, 98, 106, 10, 60, 60, 32, 47, 76, 105, 110, 101, 97, 114, 105, 122,
   101, 100, 32, 49, 32, 47, 76, 32, 55, 55, 48, 48, 32, 47, ...>>}
```

**Note:** If no output is specified the PDF will be temporary and auto-delete after the process dies.
