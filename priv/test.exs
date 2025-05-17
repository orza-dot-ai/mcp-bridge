rpa_script = File.read!("python/rpa.py")

MCPBridge.Rpa.send_message(%{
  "message" => "Hello, world!"
})
