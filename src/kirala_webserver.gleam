import gleam/bit_builder.{type BitBuilder}
import gleam/bit_string
import gleam/dynamic
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/io
import gleam/int
import gleam/list
import gleam/map
import gleam/option
import gleam/string
import kirala_elli_util

pub type Option {
  Port(Int)
}

pub fn get_port(options: List(Option), default: Int) -> Int {
  case options {
    [] -> default
    [Port(port), ..] -> port
    [_, ..rest] -> get_port(rest, default)
  }
}

fn internal_error(req: Request(BitArray)) -> Response(BitBuilder) {
  let body = bit_builder.from_string("internal error")
  response.new(500)
  |> response.set_body(body)
}

fn not_found(req: Request(BitArray)) -> Response(BitBuilder) {
  let body = bit_builder.from_string("not found:" <> req.path <> "\n")
  response.new(404)
  |> response.set_body(body)
}

pub fn add_default_header(resp: Response(BitBuilder)) -> Response(BitBuilder) {
  resp
  |> response.prepend_header("made-with", "Erlang/Gleam/Elli")
  |> response.prepend_header(
    "access-control-allow-headers",
    "content-type,x-user-token",
  )
  |> response.prepend_header(
    "access-control-allow-methods",
    "GET, POST, DELETE, PUT, PATCH, OPTIONS",
  )
  |> response.prepend_header("access-control-allow-origin", "*")
  |> response.prepend_header("access-control-max-age", "7200")
  |> response.prepend_header("strict-transport-security", "max-age=31536000")
  |> response.prepend_header("vary", "Origin")
  |> response.prepend_header("x-content-type-options", "nosniff")
  |> response.prepend_header("x-frame-options", "SAMEORIGIN")
  |> response.prepend_header(
    "cache-control",
    "max-age=0, private, must-revalidate",
  )
}

pub fn apply_middleware(
  session: session_t,
  req: Request(BitArray),
  middlewares: List(
    fn(session_t, Request(BitArray)) ->
      Result(#(session_t, Request(BitArray)), String),
  ),
) {
  case middlewares {
    [] -> Ok(#(session, req))
    [middleware, ..rest] -> {
      case middleware(session, req) {
        Ok(#(newsession, newreq)) -> apply_middleware(newsession, newreq, rest)
        Error(err) -> Error(err)
      }
    }
  }
}

pub fn router(
  middlewares: List(
    fn(session_t, Request(BitArray)) ->
      Result(#(session_t, Request(BitArray)), String),
  ),
  session: session_t,
  req: Request(BitArray),
  routes: List(
    #(String, fn(session_t, Request(BitArray)) -> Response(BitBuilder)),
  ),
) -> Result(Response(BitBuilder), String) {
  case routes {
    [] -> Error("not found:" <> req.path)
    [#(prefix, request_handler), ..rest] -> {
      //debug.tout2("- route", req.path, prefix)
      case string.starts_with(req.path, prefix) {
        True -> {
          //debug.tout1("- found", req.path)
          case apply_middleware(session, req, middlewares) {
            Ok(#(newsession, newreq)) -> {
              let resp = request_handler(newsession, newreq)
              Ok(resp)
            }
            Error(err) -> Ok(internal_error(req))
          }
        }
        False -> router(middlewares, session, req, rest)
      }
    }
  }
}

pub fn route_request(
  req: Request(BitArray),
  routes: List(fn(Request(BitArray)) -> Result(Response(BitBuilder), String)),
) -> Response(BitBuilder) {
  case routes {
    [] -> not_found(req)
    [router, ..rest] -> {
      case router(req) {
        Ok(resp) -> resp
        _ -> route_request(req, rest)
      }
    }
  }
}

pub fn start_web_server(
  name name: String,
  routers routers: List(
    fn(Request(BitArray)) -> Result(Response(BitBuilder), String),
  ),
  options options: List(Option),
) {
  io.println("-------------------------------------------------------------")
  io.println("## start_web_server" <> name)
  let port_no = get_port(options, 8080)
  io.println("- port:" <> int.to_string(port_no))
  io.println("-------------------------------------------------------------")

  let srv = fn(req: Request(BitArray)) -> Response(BitBuilder) {
    route_request(req, routers)
  }

  kirala_elli_util.start(srv, on_port: port_no)
}
