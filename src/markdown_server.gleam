import gleam/result
import gleam/string
import gleam/bit_array
import gleam/bit_builder.{type BitBuilder}
import gleam/io
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import kirala_webserver.{Port, add_default_header}
import kirala/bbmarkdown/html_renderer

pub const prefix_path = "/web_api/bbmarkdown"

pub const doc_dir = "./assets/"

pub const file_dir = "./assets/"

fn web_path(path: String) {
  prefix_path <> path
}

pub type AppSession {
  AppSession(some_info: String)
}

// ----------------------------------------------------------------------------

@external(erlang, "markdown_server_ffi", "read_text_file")
fn read_text_file(path: String) -> Result(String, String)

@external(erlang, "markdown_server_ffi", "read_raw_file")
fn read_raw_file(path: String) -> Result(BitArray, String)

@external(erlang, "markdown_server_ffi", "wait_forever")
fn wait_forever() -> Nil

@external(erlang, "markdown_server_ffi", "mime")
fn mime(path: String) -> String

fn handle_file(
  session: AppSession,
  req: Request(BitArray),
) -> Response(BitBuilder) {
  let path_components = string.split(req.path, "/")
  let [_, _, _, _, ..local_path_components] = path_components
  let local_path =
    local_path_components
    |> string.join("/")
  let filepath = file_dir <> local_path
  let assert Ok(raw) = read_raw_file(filepath)

  let response_body = bit_builder.from_bit_string(raw)
  response.new(200)
  |> response.prepend_header("Content-Type", mime(filepath))
  |> response.set_body(response_body)
}

fn handle_markdown(
  session: AppSession,
  req: Request(BitArray),
) -> Response(BitBuilder) {
  let path_components = string.split(req.path, "/")
  let [_, _, _, ..local_path_components] = path_components
  let local_path =
    local_path_components
    |> string.join("/")
  let filepath = doc_dir <> local_path
  io.println("filepath: " <> filepath)

  let assert Ok(markdown) = read_text_file(filepath)

  let content =
    "<html><meta charset='utf-8'><link href='file/style.css' rel='stylesheet' type='text/css' media='all'><body>"
    <> html_renderer.convert(markdown)
    <> "</body></html>"
  let response_body = bit_builder.from_string(content)
  response.new(200)
  |> response.prepend_header("Content-Type", "text/html; charset=UTF-8")
  |> response.set_body(response_body)
}

// ----------------------------------------------------------------------------

pub fn get_router() {
  // middleware
  let pass_through_middleware = fn(session: AppSession, req: Request(BitArray)) -> Result(
    #(AppSession, Request(BitArray)),
    String,
  ) {
    // nothing to do
    Ok(#(session, req))
  }

  let default_session = AppSession(some_info: "hello world")

  let routes = [
    #(web_path("/file"), handle_file),
    #(web_path("/"), handle_markdown),
  ]

  fn(req: Request(BitArray)) -> Result(Response(BitBuilder), String) {
    kirala_webserver.router(
      [pass_through_middleware],
      default_session,
      req,
      routes,
    )
    |> result.map(add_default_header)
  }
}

pub fn main() {
  let options = [Port(8080)]
  let routes = [get_router()]
  kirala_webserver.start_web_server("bbmarkdown server", routes, options)
  wait_forever()
}
