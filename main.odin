package main

import "core:fmt"
import "core:net"
import "core:strings"

Service_Config :: struct {
    port           : int,
    default_message: string,
    host           : net.IP4_Address,
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

build_response :: proc() -> string {
    allocator := context.allocator
    msg := "HELLO_WORLD"
    string_builder := strings.builder_make_none(allocator)
    defer strings.builder_destroy(&string_builder)

    strings.write_string(&string_builder, "HTTP/1.1 ")
    strings.write_int(&string_builder, 200)
    strings.write_string(&string_builder, " ")
	strings.write_string(&string_builder, "\nContent-Length: ")
	strings.write_int(&string_builder, len(msg))
	strings.write_string(&string_builder, "\r\n\r\n")
	strings.write_string(&string_builder, msg)
	strings.write_string(&string_builder, "\n")
    return strings.clone(strings.to_string(string_builder))
}


send_response :: proc(client: net.TCP_Socket, buffer: []u8) -> Server_Error {
    return nil
}

handle_connection :: proc(client: net.TCP_Socket) -> Server_Error {
    read_buffer := [4096]u8{}
    amount_read, net_error := net.recv_tcp(client, read_buffer[:])

    if net_error != nil {
        return Server_Error.Receive_TCP_Error 
    }

    str_message := build_response()
    message := transmute([]u8)str_message

    _, send_err := net.send_tcp(client, message[:])
    if send_err != nil {
        return Server_Error.Send_TCP_Error
    }

    fmt.println(transmute(string)message)
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
