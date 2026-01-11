defmodule JobTracker.Validation do
  @moduledoc """
  Changeset helpers shared by the schemas.
  """

  import Ecto.Changeset

  @doc """
  Validates that a field holds an absolute http(s) URL.

  A value typed without a scheme ("example.com/jobs") gets `https://` prepended,
  since that is what people paste from the address bar most of the time.
  """
  def validate_url(changeset, field) do
    changeset
    |> update_change(field, &normalize_url/1)
    |> validate_change(field, fn ^field, value ->
      if web_url?(value), do: [], else: [{field, "must be a valid URL"}]
    end)
    |> validate_length(field, max: 2000)
  end

  defp web_url?(value) do
    case URI.new(value) do
      {:ok, %URI{scheme: scheme, host: host}}
      when scheme in ["http", "https"] and is_binary(host) ->
        String.contains?(host, ".")

      _ ->
        false
    end
  end

  defp normalize_url(nil), do: nil

  defp normalize_url(value) do
    value = String.trim(value)

    cond do
      value == "" -> nil
      String.match?(value, ~r/^[a-z][a-z0-9+.-]*:\/\//i) -> value
      true -> "https://" <> value
    end
  end

  @doc """
  Trims surrounding whitespace on string fields and turns blank strings into nil.
  """
  def trim_fields(changeset, fields) do
    Enum.reduce(fields, changeset, &update_change(&2, &1, fn value -> trim(value) end))
  end

  defp trim(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp trim(value), do: value
end
