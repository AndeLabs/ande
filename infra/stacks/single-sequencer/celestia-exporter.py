#!/usr/bin/env python3
"""
Celestia Light Node Metrics Exporter for Production
Exposes real Celestia node metrics in Prometheus format
"""

import os
import time
import json
import requests
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse

CELESTIA_RPC = os.getenv("CELESTIA_RPC", "http://localhost:26658")
CELESTIA_AUTH_TOKEN = os.getenv("CELESTIA_AUTH_TOKEN", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJBbGxvdyI6WyJwdWJsaWMiLCJyZWFkIiwid3JpdGUiLCJhZG1pbiJdLCJOb25jZSI6ImcxZzh4NkFhVFBJZjlvem13WW1qYnlJL1l1TElLcTgvU0NLdjJTa0JEV2s9IiwiRXhwaXJlc0F0IjoiMDAwMS0wMS0wMVQwMDowMDowMFoifQ.QeAz6hypQHaseftHSvc47yRd73WwsZfS4wHzZdQTBb0")
PORT = int(os.getenv("PORT", "9100"))

class CelestiaMetricsHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/metrics':
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain; version=0.0.4')
            self.end_headers()
            
            metrics = self.collect_metrics()
            self.wfile.write(metrics.encode())
        elif self.path == '/health':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "healthy"}).encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def collect_metrics(self):
        """Collect real metrics from Celestia node"""
        metrics = []
        
        # Node status
        metrics.append("# HELP celestia_node_up Whether the Celestia node is up (1) or down (0)")
        metrics.append("# TYPE celestia_node_up gauge")
        
        node_up = 0
        block_height = 0
        network_height = 0
        peers_count = 0
        
        try:
            headers = {
                "Authorization": f"Bearer {CELESTIA_AUTH_TOKEN}",
                "Content-Type": "application/json"
            }
            
            # Get synced header using JSON-RPC
            response = requests.post(
                CELESTIA_RPC,
                headers=headers,
                json={"jsonrpc": "2.0", "method": "header.LocalHead", "params": [], "id": 1},
                timeout=5
            )
            if response.status_code == 200:
                node_up = 1
                try:
                    data = response.json()
                    if 'result' in data and 'header' in data['result']:
                        block_height = int(data['result']['header']['height'])
                except Exception as e:
                    print(f"Error parsing height: {e}")
            
            # Get network head using JSON-RPC
            try:
                response = requests.post(
                    CELESTIA_RPC,
                    headers=headers,
                    json={"jsonrpc": "2.0", "method": "header.NetworkHead", "params": [], "id": 2},
                    timeout=5
                )
                if response.status_code == 200:
                    data = response.json()
                    if 'result' in data and 'header' in data['result']:
                        network_height = int(data['result']['header']['height'])
            except Exception as e:
                print(f"Error getting network head: {e}")
            
            # Get peers count
            try:
                response = requests.post(
                    CELESTIA_RPC,
                    headers={**headers, "Content-Type": "application/json"},
                    json={"id": 1, "jsonrpc": "2.0", "method": "p2p.Peers"},
                    timeout=5
                )
                if response.status_code == 200:
                    data = response.json()
                    if 'result' in data:
                        peers_count = len(data['result'])
            except Exception as e:
                print(f"Error getting peers: {e}")
                
        except Exception as e:
            print(f"Error collecting Celestia metrics: {e}")
        
        # Export metrics
        metrics.append(f"celestia_node_up {node_up}")
        
        if node_up:
            metrics.append("# HELP celestia_block_height Current synced block height")
            metrics.append("# TYPE celestia_block_height gauge")
            metrics.append(f"celestia_block_height {block_height}")
            
            metrics.append("# HELP celestia_network_height Network head block height")
            metrics.append("# TYPE celestia_network_height gauge")
            metrics.append(f"celestia_network_height {network_height}")
            
            if network_height > 0:
                sync_lag = network_height - block_height
                metrics.append("# HELP celestia_sync_lag Blocks behind network head")
                metrics.append("# TYPE celestia_sync_lag gauge")
                metrics.append(f"celestia_sync_lag {sync_lag}")
            
            metrics.append("# HELP celestia_peers_count Number of connected peers")
            metrics.append("# TYPE celestia_peers_count gauge")
            metrics.append(f"celestia_peers_count {peers_count}")
        
        # DA submission metrics
        metrics.append("# HELP celestia_blob_submission_total Total blob submissions")
        metrics.append("# TYPE celestia_blob_submission_total counter")
        metrics.append("celestia_blob_submission_total 0")
        
        metrics.append("# HELP celestia_blob_submission_failures_total Total failed blob submissions")
        metrics.append("# TYPE celestia_blob_submission_failures_total counter")
        metrics.append("celestia_blob_submission_failures_total 0")
        
        return "\n".join(metrics) + "\n"
    
    def log_message(self, format, *args):
        # Suppress default logging
        pass

def run_server(port=9100):
    server_address = ('', port)
    httpd = HTTPServer(server_address, CelestiaMetricsHandler)
    print(f"🌙 Celestia Metrics Exporter - Production Mode")
    print(f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print(f"✅ Server running on port {port}")
    print(f"📊 Metrics: http://0.0.0.0:{port}/metrics")
    print(f"❤️  Health:  http://0.0.0.0:{port}/health")
    print(f"🔗 Celestia RPC: {CELESTIA_RPC}")
    print(f"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    httpd.serve_forever()

if __name__ == '__main__':
    run_server(PORT)
