-module(markdown_server_ffi).
-compile(export_all).

to_bin_string(Data) ->
    unicode:characters_to_binary(Data).

read_text_file(Filename) ->
    case file:read_file(Filename) of
        {ok, Data} ->
            {ok, to_bin_string(Data)};
        {error, Reason} ->
            {error, <<"file not found.">>}
    end.

read_raw_file(Filename) ->
    case file:read_file(Filename) of
        {ok, Data} ->
            {ok, Data};
        {error, Reason} ->
            {error, <<"file not found.">>}
    end.

wait_forever() ->
    receive
        _ ->
            wait_forever()
    end.


mime(Path) ->
	case cow_mimetypes:web(Path) of
        {A,B,C} -> <<A/binary,$/,B/binary>>;
        _ -> <<"application/octet-stream">>
    end.