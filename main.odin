package main

import "core:fmt"
import "core:net"
import "core:strings"

Service_Config :: struct {
    port           : int,
    default_message: string,
    host           : net.IP4_Address,
}

HTTP_codes :: enum {
    Ok        = 200,
    Created   = 201,
    Not_Found = 404,
}

HTTP_Response :: struct {
    status_code : HTTP_codes,
    response_str: string,
    content_type: string,
    headers     : []string,
}

Server_Error :: enum {
    Accept_TCP_Error,
    Listen_TCP_Error,
    Receive_TCP_Error,
    Send_TCP_Error,
    Create_Client_TCP_Error,
}

new_server :: proc(socket: net.TCP_Socket) -> (net.TCP_Socket, Server_Error) { 
    client, _, accept_err := net.accept_tcp(socket, net.TCP_Options{no_delay=true})
    if accept_err != nil {
        return net.TCP_Socket{}, Server_Error.Accept_TCP_Error,
    }
    return client, nil
}

serve :: proc(socket: net.TCP_Socket) -> Server_Error {
    client, create_client_err := new_server(socket)
    defer net.close(client)
    if create_client_err != nil {
        return Server_Error.Create_Client_TCP_Error,
    }
    return handle_connection(client)
}

build_response :: proc(response: HTTP_Response) -> string {
    allocator := context.allocator
    string_builder := strings.builder_make_none(allocator)
    defer strings.builder_destroy(&string_builder)

    strings.write_string(&string_builder, "HTTP/1.1 ")
    strings.write_int(&string_builder, transmute(int)response.status_code)
    strings.write_string(&string_builder, " ")
	strings.write_string(&string_builder, "\nContent-Length: ")
	strings.write_int(&string_builder, len(response.response_str))
	strings.write_string(&string_builder, "\r\n\r\n")
	strings.write_string(&string_builder, response.response_str)
	strings.write_string(&string_builder, "\n")
    return strings.clone(strings.to_string(string_builder))
}

send_response :: proc(client: net.TCP_Socket, message: []u8) -> Server_Error {
    _, send_err := net.send_tcp(client, message[:])
    if send_err != nil {
        return Server_Error.Send_TCP_Error
    }
    return nil
}

handle_connection :: proc(client: net.TCP_Socket) -> Server_Error {
    read_buffer := [4096]u8{}
    amount_read, net_error := net.recv_tcp(client, read_buffer[:])

    if net_error != nil {
        return Server_Error.Receive_TCP_Error 
    }

    http_response := HTTP_Response{
        status_code=HTTP_codes.Ok,
        response_str="HELLO_WORLD",
        headers=[]string{},
        content_type="application/json",
    }

    str_message := build_response(http_response)
    message := transmute([]u8)str_message
    send_response(client, message)
    return nil
}

run :: proc(config: Service_Config) {
    fmt.println("starting server")
    endpoint := net.Endpoint{address=config.host, port=config.port}
    socket, err := net.listen_tcp(endpoint)
    if err != nil {
        fmt.println("close")
        return
    }

    for do serve(socket)
}

main :: proc() {
    server := Service_Config{
        port=8888,
        default_message="message",
        host=net.IP4_Any,
    }
    run(server)
}
