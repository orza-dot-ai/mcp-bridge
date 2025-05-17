defmodule MCPBridge.Encounter.HTTPHandler do
  @moduledoc """
  Handles HTTP operations for FHIR Encounters.
  Provides functionality to fetch and process FHIR Encounter resources from an HTTP server.
  """

  require Logger

  @doc """
  Fetches and processes a FHIR Encounter from the configured HTTP endpoint.

  Returns:
    - `{:ok, encounter}` with the processed encounter on success
    - `{:error, reason}` on failure
  """
  def fetch_and_process_encounter() do
    timestamp = current_timestamp()
    Logger.info("[#{timestamp}] Starting FHIR Encounter processing from HTTP")

    case fetch_encounter() do
      {:ok, encounter} ->
        Logger.info("[#{timestamp}] Successfully fetched encounter with ID: #{encounter["id"]}")

        # Process the encounter (e.g., store in database, trigger workflows)
        process_result = process_encounter(encounter)
        MCPBridge.Rpa.send_message(process_result)
        # Return the encounter with processing result
        {:ok, Map.put(encounter, :processing_result, process_result)}

      {:error, reason} ->
        Logger.error("[#{timestamp}] Failed to fetch encounter: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Fetches a FHIR Encounter from the configured endpoint.

  Returns:
    - `{:ok, encounter}` with the encounter data on success
    - `{:error, reason}` on failure
  """
  def fetch_encounter() do
    endpoint = get_endpoint()

    Logger.debug("Fetching encounter from endpoint: #{endpoint}")

    # Using Finch for HTTP requests (make sure it's started in your application)
    request =
      Finch.build(:get, endpoint, [
        {"Accept", "application/fhir+json"}
      ])

    case Finch.request(request, McpBridge.Finch) do
      {:ok, %Finch.Response{status: status, body: body}} when status in 200..299 ->
        # Successfully got a response
        case Jason.decode(body) do
          {:ok, encounter} ->
            validate_encounter(encounter)

          {:error, decode_error} ->
            Logger.error("Failed to decode encounter JSON: #{inspect(decode_error)}")
            {:error, "Invalid JSON response: #{inspect(decode_error)}"}
        end

      {:ok, %Finch.Response{status: status}} ->
        # Got an error response
        {:error, "HTTP error: #{status}"}

      {:error, http_error} ->
        # Request failed
        {:error, "HTTP request failed: #{inspect(http_error)}"}
    end
  end

  @doc """
  Validates a FHIR Encounter resource.

  Returns:
    - `{:ok, encounter}` if the encounter is valid
    - `{:error, reason}` if the encounter is invalid
  """
  def validate_encounter(encounter) do
    # Basic validation to ensure it's a FHIR Encounter
    case encounter do
      %{"resourceType" => "Encounter", "id" => id} when is_binary(id) ->
        {:ok, encounter}

      %{"resourceType" => "Encounter"} ->
        {:error, "Invalid Encounter: missing ID"}

      %{"resourceType" => other} ->
        {:error, "Expected Encounter resource type, got: #{other}"}

      _ ->
        {:error, "Invalid FHIR resource: missing resourceType"}
    end
  end

  @doc """
  Processes a FHIR Encounter.
  This is where you would implement business logic for handling encounters.

  Returns a map with processing results.
  """
  def process_encounter(encounter) do
    # Log key encounter information
    Logger.info("Processing encounter ID: #{encounter["id"]}")

    patient = get_in(encounter, ["subject", "display"]) || "Unknown Patient"
    Logger.info("Patient: #{patient}")

    status = encounter["status"] || "unknown"
    Logger.info("Encounter status: #{status}")

    # Here you would typically:
    # 1. Store the encounter in your database
    # 2. Trigger any workflow processes
    # 3. Notify relevant systems or users

    # Return processing summary
    %{
      status: :success,
      timestamp: current_timestamp(),
      notes: "Encounter processed successfully",
      patient: patient,
      encounter_status: status
    }
  end

  @doc """
  Gets the FHIR server endpoint from configuration.
  Defaults to localhost:8000 if not configured.
  """
  def get_endpoint() do
    Application.get_env(:mcp_bridge, :fhir_endpoint, "http://localhost:8000")
  end

  @doc """
  Helper function to retrieve the current timestamp as a string.

  Returns a formatted DateTime string.
  """
  def current_timestamp do
    DateTime.utc_now() |> DateTime.to_string()
  end
end
