defmodule MCPBridge.Rpa do
  def send_message(message) do
    rpa_script = File.read!("python/rpa.py")

    [
      username: username,
      password: password,
      totp_secret: totp_secret,
      patient_id: patient_id,
      base_url: base_url
    ] = Application.get_env(:mcp_bridge, :erp_rpa)

    note_content = Jason.encode!(message)

    {_result_redact, _globals} =
      Pythonx.eval(rpa_script, %{
        "username" => username,
        "password" => password,
        "totp_secret" => totp_secret,
        "patient_id" => patient_id,
        "note_content" => note_content,
        "base_url" => base_url
      })
  end
end
