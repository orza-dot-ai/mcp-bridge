#!/usr/bin/env python3
"""
A simple HTTP server that returns FHIR Encounter JSON.
Run this script to start the server on port 8000.
"""

from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import datetime
import uuid

class FHIRRequestHandler(BaseHTTPRequestHandler):
    def _set_headers(self):
        self.send_response(200)
        self.send_header('Content-type', 'application/fhir+json')
        self.send_header('Access-Control-Allow-Origin', '*')  # Allow CORS
        self.end_headers()
    
    def do_GET(self):
        # Handle GET requests - return a FHIR Encounter resource
        self._set_headers()
        
        # Get current time for timestamps
        now = datetime.datetime.utcnow().isoformat() + "Z"
        
        # Create a FHIR Encounter resource
        encounter = {
            "resourceType": "Encounter",
            "id": str(uuid.uuid4()),
            "meta": {
                "versionId": "1",
                "lastUpdated": now
            },
            "status": "in-progress",
            "class": {
                "system": "http://terminology.hl7.org/CodeSystem/v3-ActCode",
                "code": "AMB",
                "display": "ambulatory"
            },
            "subject": {
                "reference": "Patient/example",
                "display": "John Doe"
            },
            "participant": [
                {
                    "type": [
                        {
                            "coding": [
                                {
                                    "system": "http://terminology.hl7.org/CodeSystem/v3-ParticipationType",
                                    "code": "PPRF",
                                    "display": "primary performer"
                                }
                            ]
                        }
                    ],
                    "individual": {
                        "reference": "Practitioner/example",
                        "display": "Dr. Jane Smith"
                    }
                }
            ],
            "period": {
                "start": now
            },
            "reasonCode": [
                {
                    "coding": [
                        {
                            "system": "http://snomed.info/sct",
                            "code": "386661006",
                            "display": "Fever"
                        }
                    ]
                }
            ],
            "serviceProvider": {
                "reference": "Organization/example",
                "display": "Community Hospital"
            }
        }
        
        # Send the JSON response
        self.wfile.write(json.dumps(encounter, indent=2).encode())
    
    def do_OPTIONS(self):
        # Handle preflight requests for CORS
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

def run_server(server_class=HTTPServer, handler_class=FHIRRequestHandler, port=8000):
    """Run the HTTP server on the specified port"""
    server_address = ('', port)
    httpd = server_class(server_address, handler_class)
    print(f"Starting FHIR server on port {port}...")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping server...")
        httpd.server_close()

if __name__ == "__main__":
    run_server()