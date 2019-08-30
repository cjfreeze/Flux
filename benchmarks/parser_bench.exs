request = """
GET https://www.google.com/search?q=http+request&ie=utf-8&oe=utf-8 HTTP/1.1\r
Host: www.google.com\r
User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.13; rv:56.0) Gecko/20100101 Firefox/56.0\r
Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8\r
Accept-Language: en-US,en;q=0.5\r
Accept-Encoding: gzip, deflate, br\r
Connection: keep-alive\r
Upgrade-Insecure-Requests: 1\r
Cache-Control: max-age=0\r
\r
"""
conn = %Flux.Conn{}

Benchee.run(%{
  "parser"    => fn -> Flux.HTTP.Parser.parse(conn, request) end,
}, time: 10, memory_time: 2)
