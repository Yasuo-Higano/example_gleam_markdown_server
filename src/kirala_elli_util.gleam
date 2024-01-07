import gleam/erlang/atom.{type Atom}
import gleam/dynamic.{type Dynamic}
import gleam/otp/actor
import gleam/otp/supervisor
import gleam/http
import gleam/http/service.{type Service}
import gleam/http/request.{Request}
import gleam/http/response.{Response}
import gleam/list
import gleam/option
import gleam/pair
import gleam/result
import gleam/string
import gleam/bit_builder.{type BitBuilder}
import gleam/bit_string
import gleam/erlang/process.{type Pid}

pub type ElliRequest

pub type ElliResponse =
  #(Int, List(http.Header), BitBuilder)

type StartLinkOption {
  Callback(Atom)
  CallbackArgs(fn(ElliRequest) -> ElliResponse)
  Port(Int)
  MaxBodySize(Int)
}

@external(erlang, "binary", "split")
fn split(a: String, b: List(String)) -> List(String)

@external(erlang, "elli", "start_link")
fn ffi_start_link(a: List(StartLinkOption)) -> Result(Pid, Dynamic)

@external(erlang, "elli_request", "body")
pub fn get_body(a: ElliRequest) -> BitArray

@external(erlang, "elli_request", "headers")
pub fn get_headers(a: ElliRequest) -> List(http.Header)

@external(erlang, "gleam_elli_native", "get_host")
pub fn get_host(a: ElliRequest) -> String

@external(erlang, "elli_request", "method")
fn get_dynamic_method(a: ElliRequest) -> Dynamic

@external(erlang, "io", "format")
fn log(a: String, b: List(String)) -> Dynamic

pub fn get_method(req) {
  req
  |> get_dynamic_method
  |> http.method_from_dynamic
  |> result.unwrap(http.Get)
}

@external(erlang, "elli_request", "port")
fn get_dynamic_port(a: ElliRequest) -> Dynamic

pub fn get_port(req) {
  req
  |> get_dynamic_port
  |> dynamic.int
  |> option.from_result
}

@external(erlang, "elli_request", "scheme")
fn get_dynamic_scheme(a: ElliRequest) -> Dynamic

pub fn get_scheme(req) -> http.Scheme {
  let scheme =
    req
    |> get_dynamic_scheme
    |> dynamic.string
    |> result.unwrap("")
    |> string.lowercase
  case scheme {
    "https" -> http.Https
    _ -> http.Http
  }
}

@external(erlang, "elli_request", "query_str")
pub fn get_query(a: ElliRequest) -> String

@external(erlang, "elli_request", "raw_path")
pub fn get_raw_path(a: ElliRequest) -> String

pub fn get_path(request: ElliRequest) -> String {
  let raw_path = get_raw_path(request)
  raw_path
  |> split(["#", "?"])
  |> list.first
  |> result.unwrap(raw_path)
}

// external fn await_shutdown(process.Pid) -> Nil =
//   "gleam_elli_native" "await_shutdown"

pub fn convert_header_to_lowercase(header: http.Header) -> http.Header {
  pair.map_first(header, fn(key) { string.lowercase(key) })
}

fn service_to_elli_handler(
  service: Service(BitArray, BitBuilder),
) -> fn(ElliRequest) -> ElliResponse {
  fn(req) {
    let resp =
      Request(
        scheme: get_scheme(req),
        method: get_method(req),
        host: get_host(req),
        port: get_port(req),
        path: get_path(req),
        query: option.Some(get_query(req)),
        headers: get_headers(req)
        |> list.map(convert_header_to_lowercase),
        body: get_body(req),
      )
      |> service
    let Response(status, headers, body) = resp
    #(status, headers, body)
  }
}

@external(erlang, "gleam_elli_native", "await_shutdown")
fn await_shutdown(a: process.Pid) -> Nil

/// Start a new Elli web server process which runs concurrently to the current
/// process.
///
/// If you want to run the web server but don't need to do anything else with
/// the current process you may want to use the `become` function instead.
///
pub fn start(
  service: Service(BitArray, BitBuilder),
  on_port number: Int,
) -> Result(Pid, Dynamic) {
  [
    Port(number),
    Callback(atom.create_from_string("gleam_elli_native")),
    CallbackArgs(service_to_elli_handler(service)),
    MaxBodySize(1024 * 1024 * 10),
  ]
  |> ffi_start_link
}

/// Start an Elli web server with the current process.
///
/// This function returns if the Elli web server fails to start or if it was
/// shut down after successfully starting.
///
pub fn become(
  service: Service(BitArray, BitBuilder),
  on_port number: Int,
) -> Result(Nil, Dynamic) {
  service
  |> start(number)
  |> result.map(await_shutdown)
}
