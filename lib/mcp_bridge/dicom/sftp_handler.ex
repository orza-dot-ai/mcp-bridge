defmodule MCPBridge.Dicom.SFTPHandler do
  @moduledoc """
  Handles SFTP operations for DICOM files.
  Provides functionality to fetch and process DICOM files from a directory,
  including extracting metadata using Python integration.
  """

  require Logger

  @doc """
  Fetches and processes DICOM files from the priv/dicom directory.

  Prints "Hello World" and logs all filenames with their sizes found in the directory.
  Also extracts DICOM metadata from each file using Python integration.

  Returns:
    - `{:ok, file_info}` with a list of processed files and their details on success
    - `{:error, reason}` on failure
  """
  def fetch_and_process_file() do
    # Get current timestamp
    timestamp = current_timestamp()

    # Log operation start
    Logger.info("[#{timestamp}] Starting DICOM file processing from SFTP")

    # Print "Hello World" (this is the actual requirement)
    IO.puts("[#{timestamp}] Hello World")

    # Get the path to the priv/dicom directory
    dicom_dir = Application.app_dir(:mcp_bridge, "priv/dicom")

    # Loop through all files in the directory
    case File.ls(dicom_dir) do
      {:ok, files} ->
        # Log the number of files found
        Logger.info("[#{timestamp}] Found #{length(files)} DICOM files in #{dicom_dir}")

        # Process each file with size information and metadata
        file_info =
          Enum.map(files, fn filename ->
            full_path = Path.join(dicom_dir, filename)

            # Get file size
            size_result =
              case File.stat(full_path) do
                {:ok, %{size: size}} ->
                  # Convert to human-readable format
                  format_file_size(size)

                {:error, reason} ->
                  Logger.warning(
                    "[#{timestamp}] Failed to get size for #{filename}: #{inspect(reason)}"
                  )

                  "unknown size"
              end

            Logger.info("[#{timestamp}] Processing DICOM file: #{filename} (#{size_result})")

            # Extract metadata if file has .dcm extension
            metadata =
              if String.ends_with?(String.downcase(filename), ".dcm") do
                try do
                  parse_dicom_metadata!(full_path)
                rescue
                  e ->
                    Logger.error(
                      "[#{timestamp}] Failed to parse DICOM metadata for #{filename}: #{inspect(e)}"
                    )

                    %{"error" => "Failed to parse DICOM metadata"}
                end
              else
                %{"note" => "Not a DICOM file"}
              end
          # Extract metadata if file has .dcm extension
          metadata = if String.ends_with?(String.downcase(filename), ".dcm") do
            try do
              parse_dicom_metadata!(full_path)
            rescue
              e ->
                Logger.error("[#{timestamp}] Failed to parse DICOM metadata for #{filename}: #{inspect(e)}")
                %{"error" => "Failed to parse DICOM metadata"}
            end
          else
            %{"note" => "Not a DICOM file"}
          end

          Platform.Rpa.send_message(metadata)

            # Return a map with filename, size, and metadata information
            %{
              filename: filename,
              path: full_path,
              size: size_result,
              metadata: metadata
            }
          end)

        # Return the list of processed file information
        {:ok, file_info}

      {:error, reason} ->
        Logger.error("[#{timestamp}] Failed to read DICOM directory: #{inspect(reason)}")

        # In case the directory doesn't exist, try to create it
        File.mkdir_p(dicom_dir)

        # Return error
        {:error, "Failed to read DICOM directory: #{inspect(reason)}"}
    end
  end

  @doc """
  Extracts metadata from a DICOM file using Python integration.

  ## Parameters
    - `file_path`: The path to the DICOM file

  ## Returns
    - A map containing the DICOM metadata

  ## Raises
    - Various exceptions if the Python integration fails or the file isn't a valid DICOM file
  """
  def parse_dicom_metadata!(file_path) do
    parse_dicom_metadata_script = File.read!("python/parse_dicom_metadata.py")
    {metadata, _globals} = Pythonx.eval(parse_dicom_metadata_script, %{"file_path" => file_path})
    Pythonx.decode(metadata)
  end

  @doc """
  Formats file size from bytes to a human-readable string.

  ## Examples
      iex> format_file_size(1024)
      "1.0 KB"

      iex> format_file_size(1048576)
      "1.0 MB"
  """
  def format_file_size(size_in_bytes) when is_integer(size_in_bytes) do
    cond do
      size_in_bytes < 1024 ->
        "#{size_in_bytes} B"

      size_in_bytes < 1024 * 1024 ->
        kb = size_in_bytes / 1024
        "#{:erlang.float_to_binary(kb, decimals: 1)} KB"

      size_in_bytes < 1024 * 1024 * 1024 ->
        mb = size_in_bytes / (1024 * 1024)
        "#{:erlang.float_to_binary(mb, decimals: 1)} MB"

      true ->
        gb = size_in_bytes / (1024 * 1024 * 1024)
        "#{:erlang.float_to_binary(gb, decimals: 1)} GB"
    end
  end

  @doc """
  Helper function to retrieve the current timestamp as a string.

  Returns a formatted DateTime string.
  """
  def current_timestamp do
    DateTime.utc_now() |> DateTime.to_string()
  end
end
