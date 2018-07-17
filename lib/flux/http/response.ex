defmodule Flux.HTTP.Response do
  @moduledoc """
  Documentation for Flux.HTTP.Response.
  """

  require Logger

  alias Flux.HTTP.Encoder

  version =
    Flux.Mixfile.project()
    |> Keyword.get(:version)

  @version version
  {os, _} = :os.type()
  @os "#{os}"

  @spec build(Flux.Conn.t()) :: iodata
  def build(%{
        status: status,
        version: version,
        method: method,
        resp_headers: headers,
        resp_body: body,
        accept_encoding: accepted_codings,
        resp_type: resp_type
      }) do
    with {:ok, coding} <- Encoder.which_coding(accepted_codings),
         {:ok, encoded_body} <- Encoder.encode(coding, body),
         {:resp_type, :normal} <- {:resp_type, resp_type} do
      headers = add_encoding_header(headers, coding)
      response(status, version, encoded_body, headers, method)
    else
      {:resp_type, :raw} ->
        raw_response(status, version, headers)
      {:error, status} ->
        error_response(status, version, headers, method)
    end
  end

  def response(status, version, body, headers, method) do
    [
      status_line(version, status),
      date(),
      server(),
      content_length_header(body)
    ]
    |> add_headers(headers)
    |> add_body(body, method)
  end

  def file_response(status, version, length, headers, method) do
    [
      status_line(version, status),
      date(),
      server(),
      content_length_header(length)
    ]
    |> add_headers(headers)
    |> add_body(nil, method)
  end

  def raw_response(status, version, headers) do
    [
      status_line(version, status)
    ]
    |> add_headers(headers)
    |> add_body(nil, nil)
  end

  def error_response(status, version, headers, method) do
    [
      status_line(version, status),
      date(),
      server()
    ]
    |> add_headers(headers)
    |> add_body(status_message(status), method)
  end

  defp status_line(version, status) do
    ["#{version} #{status} ", status_message(status), "\r\n"]
  end

  defp date do
    [Flux.Date.now(), "\r\n"]
  end

  defp server do
    ["Server: ", "Flux/", @version, " (", @os, ")", "\r\n"]
  end

  defp add_encoding_header(headers, coding) do
    [{"content-encoding", coding} | headers]
  end

  defp content_length_header(length) when is_integer(length) do
    ["content-length: ", "#{length}", "\r\n"]
  end

  defp content_length_header(body) do
    content_length =
      body
      |> IO.iodata_length()
      |> Integer.to_string()

    ["content-length: ", content_length, "\r\n"]
  end

  defp add_headers(response, [{key, value} | tail]) do
    [response | [key, ": ", value, "\r\n"]]
    |> add_headers(tail)
  end

  defp add_headers(response, []) do
    response
  end

  defp add_body(response, _, :head), do: [response | "\r\n"]

  defp add_body(reponse, nil, _) do
    [reponse | ["\r\n"]]
  end

  defp add_body(reponse, body, _) do
    [reponse | ["\r\n", body]]
  end

  # 1×× Informational
  defp status_message(100), do: "Continue"
  defp status_message(101), do: "Switching Protocols"
  defp status_message(102), do: "Processing"

  # 2×× Success
  defp status_message(200), do: "OK"
  defp status_message(201), do: "Created"
  defp status_message(202), do: "Accepted"
  defp status_message(203), do: "Non-authoritative Information"
  defp status_message(204), do: "No Content"
  defp status_message(205), do: "Reset Content"
  defp status_message(206), do: "Partial Content"
  defp status_message(207), do: "Multi-Status"
  defp status_message(208), do: "Already Reported"
  defp status_message(226), do: "IM Used"

  # 3×× Redirection
  defp status_message(300), do: "Multiple Choices"
  defp status_message(301), do: "Moved Permanently"
  defp status_message(302), do: "Found"
  defp status_message(303), do: "See Other"
  defp status_message(304), do: "Not Modified"
  defp status_message(305), do: "Use Proxy"
  defp status_message(307), do: "Temporary Redirect"
  defp status_message(308), do: "Permanent Redirect"

  # 4×× Client Error
  defp status_message(400), do: "Bad Request"
  defp status_message(401), do: "Unauthorized"
  defp status_message(402), do: "Payment Required"
  defp status_message(403), do: "Forbidden"
  defp status_message(404), do: "Not Found"
  defp status_message(405), do: "Method Not Allowed"
  defp status_message(406), do: "Not Acceptable"
  defp status_message(407), do: "Proxy Authentication Required"
  defp status_message(408), do: "Request Timeout"
  defp status_message(409), do: "Conflict"
  defp status_message(410), do: "Gone"
  defp status_message(411), do: "Length Required"
  defp status_message(412), do: "Precondition Failed"
  defp status_message(413), do: "Payload Too Large"
  defp status_message(414), do: "Request-URI Too Long"
  defp status_message(415), do: "Unsupported Media Type"
  defp status_message(416), do: "Requested Range Not Satisfiable"
  defp status_message(417), do: "Expectation Failed"
  defp status_message(418), do: "I'm a teapot"
  defp status_message(421), do: "Misdirected Request"
  defp status_message(422), do: "Unprocessable Entity"
  defp status_message(423), do: "Locked"
  defp status_message(424), do: "Failed Dependency"
  defp status_message(426), do: "Upgrade Required"
  defp status_message(428), do: "Precondition Required"
  defp status_message(429), do: "Too Many Requests"
  defp status_message(431), do: "Request Header Fields Too Large"
  defp status_message(444), do: "Connection Closed Without Response"
  defp status_message(451), do: "Unavailable For Legal Reasons"
  defp status_message(499), do: "Client Closed Request"

  # 5×× Server Error
  defp status_message(500), do: "Internal Server Error"
  defp status_message(501), do: "Not Implemented"
  defp status_message(502), do: "Bad Gateway"
  defp status_message(503), do: "Service Unavailable"
  defp status_message(504), do: "Gateway Timeout"
  defp status_message(505), do: "HTTP Version Not Supported"
  defp status_message(506), do: "Variant Also Negotiates"
  defp status_message(507), do: "Insufficient Storage"
  defp status_message(508), do: "Loop Detected"
  defp status_message(510), do: "Not Extended"
  defp status_message(511), do: "Network Authentication Required"
  defp status_message(599), do: "Network Connect Timeout Error"

  # Other
  defp status_message(_), do: raise("Unrecognized Status Code")
end
