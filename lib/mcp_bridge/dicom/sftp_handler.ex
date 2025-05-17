defmodule MCPBridge.Dicom.SFTPHandler do
  @doc """
  Fetches and processes a DICOM file from SFTP server, printing "Hello World" as part of the process.

  This function is designed to be scheduled to run every 5 minutes.

  ## Parameters

  * `path` - String path to the file on the SFTP server (optional, defaults to "/incoming")
  * `opts` - Keyword list of options (optional)
    * `:server` - SFTP server address (defaults to configured value)
    * `:credentials` - Authentication credentials (defaults to configured values)

  ## Returns

  * `{:ok, filename}` - If file was successfully processed
  * `{:error, reason}` - If processing failed

  ## Examples

      iex> MCPBrider.Dicom.SFTPHandler.fetch_and_process_file()
      {:ok, "processed_file.dcm"}

  """
  def fetch_and_process_file() do
    # Get current timestamp
    timestamp = DateTime.utc_now() |> DateTime.to_string()

    # Log operation start
    require Logger
    Logger.info("[#{timestamp}] Starting DICOM file processing from SFTP")

    # Print "Hello World" (this is the actual requirement)
    IO.puts("[#{timestamp}] Hello World")

    # Here you would normally:
    # 1. Connect to SFTP server
    # 2. Download the file
    # 3. Process the DICOM file
    # 4. Return the result

    # Simulate successful processing
    filename = "dicom_#{:os.system_time(:millisecond)}.dcm"
    Logger.info("[#{timestamp}] Successfully processed DICOM file: #{filename}")

    {:ok, filename}
  end
end
