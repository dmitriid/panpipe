defmodule Panpipe.Pandoc do
  @moduledoc """
  Wrapper around the `pandoc` CLI.

  TODO: setting the `pandoc` path
  """

  @pandoc "pandoc"

  @api_version [1, 17, 2]

  def api_version(), do: @api_version


  def version,  do: extract_from_version_string ~R/pandoc (\d+\.\d+.*)/

  def data_dir, do: extract_from_version_string ~R/Default user data directory: (.+)/

  defp extract_from_version_string(regex) do
    with {:ok, version_string} <- call(version: true),
         [_, match]            <- Regex.run(regex, version_string) do
      match
    else
      _ -> nil
    end
  end


  @info_path "priv/pandoc/info"
  @input_formats_file       Path.join(@info_path, "input-formats.txt")
  @output_formats_file      Path.join(@info_path, "output-formats.txt")
  @extensions_file          Path.join(@info_path, "extensions.txt")
  @highlight_languages_file Path.join(@info_path, "highlight-languages.txt")
  @highlight_styles_file    Path.join(@info_path, "highlight-styles.txt")

  @doc false
  def input_formats_file, do: @input_formats_file
  @doc false
  def output_formats_file, do: @output_formats_file
  @doc false
  def extensions_file, do: @extensions_file
  @doc false
  def highlight_languages_file, do: @highlight_languages_file
  @doc false
  def highlight_styles_file, do: @highlight_styles_file

  @external_resource @input_formats_file
  @external_resource @output_formats_file
  @external_resource @extensions_file
  @external_resource @highlight_languages_file
  @external_resource @highlight_styles_file

  @input_formats       Panpipe.Pandoc.Info.read(@input_formats_file)
  @output_formats      Panpipe.Pandoc.Info.read(@output_formats_file)
  @highlight_languages Panpipe.Pandoc.Info.read(@highlight_languages_file)
  @highlight_styles    Panpipe.Pandoc.Info.read(@highlight_styles_file)
  @extensions          Panpipe.Pandoc.Info.read_without_flag(@extensions_file)

  def input_formats(),       do: @input_formats
  def output_formats(),      do: @output_formats
  def highlight_languages(), do: @highlight_languages
  def highlight_styles(),    do: @highlight_styles
  def extensions(),          do: @extensions


  @doc """
  Calls the `pandoc` command.

  For a description of the arguments refer to the [Pandoc User’s Guide](http://pandoc.org/MANUAL.html).

  You can provide any of Pandoc's supported options in their long form without
  the leading double dashes and all other dashes replaced by underscores.

  Other than that the only difference are a couple of default values:

  - Flag options must provide a `true` value, eg. the verbose option can be set
    with the option `verbose: true`

  ## Examples

      iex> "# A Markdown Document\\nLorem ipsum" |> Panpipe.Pandoc.call()
      {:ok, ~s[<h1 id=\"a-markdown-document\">A Markdown Document</h1>\\n<p>Lorem ipsum</p>\\n]}

      iex> "# A Markdown Document\\n..." |> Panpipe.Pandoc.call(output: "test/output/example.html")
      {:ok, nil}

      iex> Panpipe.Pandoc.call(input: "test/fixtures/example.md")
      {:ok, ~s[<h1 id=\"a-markdown-document\">A Markdown Document</h1>\\n<p>Lorem ipsum</p>\\n]}

      iex> Panpipe.Pandoc.call(input: "test/fixtures/example.md", output: "test/output/example.html")
      {:ok, nil}

  """
  def call(input) when is_binary(input) do
    Keyword.new(input: {:data, input}) |> call()
  end

  def call(opts) do
    with %Porcelain.Result{status: 0} = result <- exec(opts) do
      {:ok, output(result, opts)}
    else
      error ->
        {:error, error}
    end
  end

  def call(input, opts) do
    opts |> Keyword.put(:input, {:data, input}) |> call()
  end

  defp exec(opts) do
    case Keyword.pop(opts, :input) do
      {input_file, opts} when is_binary(input_file) ->
        Porcelain.exec(@pandoc, [input_file | build_opts(opts)])

      {{:data, data}, opts} ->
        # TODO: This depends on Goon to be installed and configured properly, since the basic Porcelain driver won't work: <https://github.com/alco/porcelain/issues/37>
        Porcelain.exec(@pandoc, build_opts(opts), in: data)

      {nil, _} ->
        if non_conversion_command?(opts) do
          Porcelain.exec(@pandoc, build_opts(opts))
        else
          raise "No input specified."
        end
    end
  end

  defp non_conversion_command?(opts) do
    Keyword.has_key?(opts, :version)
  end

  defp output(result, opts) do
    case Keyword.get(opts, :output) do
      nil   -> result.out
      _file -> nil
    end
  end

  defp build_opts(opts) do
    opts
    |> Enum.map(&build_opt/1)
  end

  defp build_opt({opt, true}),  do: "#{build_opt(opt)}"
  defp build_opt({opt, value}), do: "#{build_opt(opt)}=#{to_string(value)}"

  defp build_opt(opt) when is_atom(opt),
    do: "--#{opt |> to_string() |> String.replace("_", "-")}"

  def ast(opts) do
    with {:ok, json} <- to_json(opts) do
      Jason.decode(json)
    end
  end

  def to_json(opts), do: opts |> Keyword.put(:to, "json") |> call()

end