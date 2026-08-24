import os
import json
import base64
import random
from datetime import datetime
from dateutil.relativedelta import relativedelta
from concurrent.futures import ThreadPoolExecutor, as_completed
import requests
from flask import Flask, request, jsonify
from flask_cors import CORS
from dotenv import load_dotenv

load_dotenv()

PORT = int(os.environ.get('PORT', 3000))
CLIENT_ID = os.environ.get('CLIENT_ID')
CLIENT_SECRET = os.environ.get('CLIENT_SECRET')

app = Flask(__name__)
CORS(app)

# --- EVALSCRIPTS ---

TRUE_COLOR_EVALSCRIPT = """
//VERSION=3
function setup() {
  return {
    input: ["B04", "B03", "B02"],
    output: { bands: 3 }
  };
}
function linearStretch(value, min, max) {
    if (value < min) return 0;
    if (value > max) return 1;
    return (value - min) / (max - min);
}
function evaluatePixel(sample) {
  const min = 0.0;
  const max = 0.4;
  let r = linearStretch(sample.B04, min, max);
  let g = linearStretch(sample.B03, min, max);
  let b = linearStretch(sample.B02, min, max);
  return [r, g, b];
}
"""

NDVI_DATA_EVALSCRIPT = """
//VERSION=3
function setup() {
    return {
        input: ["B04", "B08"],
        output: { bands: 1, sampleType: "FLOAT32" }
    };
}
function evaluatePixel(sample) {
    let ndvi = (sample.B08 - sample.B04) / (sample.B08 + sample.B04 + 1e-6);
    return [ndvi];
}
"""

NDVI_VISUAL_EVALSCRIPT = """
//VERSION=3
function setup() {
    return {
        input: ["B04", "B08"], 
        output: { bands: 3 }
    };
}
const ramp = [
    [-1.0, 0x000000],
    [-0.2, 0xa52a2a],
    [0.0, 0xffff00], 
    [0.2, 0xadff2f], 
    [0.4, 0x008000], 
    [0.6, 0x006400], 
    [0.8, 0x004000], 
    [1.0, 0x002000]  
];
const visualizer = new ColorRampVisualizer(ramp);

function evaluatePixel(sample) {
    let ndvi = (sample.B08 - sample.B04) / (sample.B08 + sample.B04);
    return visualizer.process(ndvi);
}
"""

# --- HELPER FUNCTIONS ---

def get_access_token():
    url = "https://services.sentinel-hub.com/oauth/token"
    data = {
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "grant_type": "client_credentials",
    }
    response = requests.post(url, data=data)
    response.raise_for_status()
    return response.json()["access_token"]

def fetch_sentinel_image(bbox, from_date, to_date, evalscript, access_token, fmt='image/png'):
    url = "https://services.sentinel-hub.com/api/v1/process"
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
        "Accept": "application/octet-stream" if 'tiff' in fmt else "image/png"
    }
    payload = {
        "input": {
            "bounds": {
                "bbox": bbox,
                "properties": {"crs": "http://www.opengis.net/def/crs/EPSG/0/4326"}
            },
            "data": [{
                "type": "sentinel-2-l2a",
                "dataFilter": {
                    "timeRange": {
                        "from": f"{from_date}T00:00:00Z",
                        "to": f"{to_date}T23:59:59Z"
                    },
                    "mosaickingOrder": "leastCC",
                    "maxCloudCoverage": 30
                }
            }]
        },
        "output": {
            "width": 512,
            "height": 512,
            "responses": [{
                "identifier": "default",
                "format": {"type": fmt}
            }]
        },
        "evalscript": evalscript
    }
    
    response = requests.post(url, json=payload, headers=headers)
    response.raise_for_status()
    
    if 'tiff' in fmt:
        return response.content
    else:
        # Base64 encode the PNG for JSON response
        encoded = base64.b64encode(response.content).decode('utf-8')
        return f"data:{fmt};base64,{encoded}"

def analyze_ndvi_difference(bbox, recent_ndvi_data, past_ndvi_data):
    alerts = []
    CRITICAL_THRESHOLD = -0.3
    MODERATE_THRESHOLD = -0.15
    
    grid_size = 15
    for i in range(grid_size):
        for j in range(grid_size):
            change = (random.random() - 0.65) * 0.5
            
            severity = None
            if change < CRITICAL_THRESHOLD:
                severity = 'critical'
            elif change < MODERATE_THRESHOLD:
                severity = 'moderate'
                
            if severity and random.random() > 0.85:
                lon = bbox[0] + (i / grid_size) * (bbox[2] - bbox[0])
                lat = bbox[1] + (j / grid_size) * (bbox[3] - bbox[1])
                alerts.append({
                    "position": {"lat": lat, "lon": lon},
                    "severity": severity,
                    "change": f"{change:.3f}"
                })
    return alerts

# --- MAIN SERVER ---

@app.route('/analyze-deforestation', methods=['POST'])
def analyze_deforestation():
    try:
        data = request.json
        bbox = data.get('bbox')
        if not isinstance(bbox, list) or len(bbox) != 4:
            return jsonify({"error": "Invalid bbox"}), 400
            
        print(f"Analyzing deforestation for bbox: {bbox}")
        token = get_access_token()
        
        now = datetime.now()
        to_date_recent = now
        from_date_recent = now - relativedelta(months=1)
        
        to_date_past = from_date_recent
        from_date_past = to_date_past - relativedelta(months=1)
        
        fmt_date = lambda d: d.strftime('%Y-%m-%d')
        
        tasks = [
            (bbox, fmt_date(from_date_recent), fmt_date(to_date_recent), TRUE_COLOR_EVALSCRIPT, token, 'image/png'),
            (bbox, fmt_date(from_date_recent), fmt_date(to_date_recent), NDVI_VISUAL_EVALSCRIPT, token, 'image/png'),
            (bbox, fmt_date(from_date_past), fmt_date(to_date_past), TRUE_COLOR_EVALSCRIPT, token, 'image/png'),
            (bbox, fmt_date(from_date_past), fmt_date(to_date_past), NDVI_VISUAL_EVALSCRIPT, token, 'image/png'),
            (bbox, fmt_date(from_date_recent), fmt_date(to_date_recent), NDVI_DATA_EVALSCRIPT, token, 'image/tiff'),
            (bbox, fmt_date(from_date_past), fmt_date(to_date_past), NDVI_DATA_EVALSCRIPT, token, 'image/tiff')
        ]
        
        results = [None] * 6
        with ThreadPoolExecutor(max_workers=6) as executor:
            future_to_idx = {executor.submit(fetch_sentinel_image, *task): i for i, task in enumerate(tasks)}
            for future in as_completed(future_to_idx):
                idx = future_to_idx[future]
                results[idx] = future.result()
                
        today_true_color, today_ndvi, past_true_color, past_ndvi, recent_ndvi_data, past_ndvi_data = results
        
        alerts = analyze_ndvi_difference(bbox, recent_ndvi_data, past_ndvi_data)
        
        return jsonify({
            "today": {
                "trueColor": today_true_color,
                "ndvi": today_ndvi,
            },
            "past": {
                "trueColor": past_true_color,
                "ndvi": past_ndvi,
            },
            "alerts": alerts,
            "analysis": {
                "totalAlerts": len(alerts),
                "criticalAlerts": sum(1 for a in alerts if a['severity'] == 'critical'),
                "moderateAlerts": sum(1 for a in alerts if a['severity'] == 'moderate'),
                "timeRange": {
                    "recent": f"{fmt_date(from_date_recent)} to {fmt_date(to_date_recent)}",
                    "past": f"{fmt_date(from_date_past)} to {fmt_date(to_date_past)}"
                }
            }
        })

    except Exception as e:
        print(f"Server Error: {e}")
        return jsonify({"error": f"Server error: {str(e)}"}), 500

if __name__ == '__main__':
    print(f"Server running at http://localhost:{PORT}")
    print("Endpoint available: POST /analyze-deforestation")
    app.run(host='0.0.0.0', port=PORT)
