import os
from datetime import datetime, timezone
import httpx
import numpy as np
import rasterio
from dateutil.relativedelta import relativedelta
from dotenv import load_dotenv
from fastapi import FastAPI
from pydantic import BaseModel

load_dotenv()

CLIENT_ID = os.getenv("CLIENT_ID")
CLIENT_SECRET = os.getenv("CLIENT_SECRET")

app = FastAPI()


NDVI_EVALSCRIPT = """
//VERSION=3

function setup() {
    return {
        input: ["B04", "B08"],
        output: {
            bands: 1,
            sampleType: "FLOAT32"
        }
    };
}

function evaluatePixel(sample) {
    return [
        (sample.B08 - sample.B04) /
        (sample.B08 + sample.B04 + 1e-6)
    ];
}
"""


class AnalysisRequest(BaseModel):
    bbox: list[float]


async def get_token(client):
    response = await client.post(
        "https://services.sentinel-hub.com/oauth/token",
        data={
            "client_id": CLIENT_ID,
            "client_secret": CLIENT_SECRET,
            "grant_type": "client_credentials",
        },
    )

    response.raise_for_status()
    return response.json()["access_token"]


async def get_ndvi(client, bbox, start, end, token):
    response = await client.post(
        "https://services.sentinel-hub.com/api/v1/process",
        headers={
            "Authorization": f"Bearer {token}",
        },
        json={
            "input": {
                "bounds": {
                    "bbox": bbox,
                },
                "data": [
                    {
                        "type": "sentinel-2-l2a",
                        "dataFilter": {
                            "timeRange": {
                                "from": f"{start}T00:00:00Z",
                                "to": f"{end}T23:59:59Z",
                            },
                            "mosaickingOrder": "leastCC",
                            "maxCloudCoverage": 30,
                        },
                    }
                ],
            },
            "output": {
                "width": 512,
                "height": 512,
                "responses": [
                    {
                        "identifier": "default",
                        "format": {
                            "type": "image/tiff"
                        },
                    }
                ],
            },
            "evalscript": NDVI_EVALSCRIPT,
        },
    )

    response.raise_for_status()
    return response.content


def read_ndvi(data):
    with rasterio.MemoryFile(data) as file:
        with file.open() as image:
            return image.read(1)


def find_deforestation(recent, past, bbox):
    change = recent - past

    rows, cols = np.where(change < -0.15)

    height, width = change.shape

    min_lon, min_lat, max_lon, max_lat = bbox

    alerts = []

    for row, col in zip(rows, cols):
        value = float(change[row, col])

        alerts.append({
            "lat": max_lat - (row / height) * (max_lat - min_lat),
            "lon": min_lon + (col / width) * (max_lon - min_lon),
            "change": round(value, 3),
        })

    return alerts


@app.post("/analyze-deforestation")
async def analyze(req: AnalysisRequest):

    now = datetime.now(timezone.utc)

    recent_end = now
    recent_start = now - relativedelta(months=1)

    past_end = recent_start
    past_start = past_end - relativedelta(months=1)

    recent_start = recent_start.strftime("%Y-%m-%d")
    recent_end = recent_end.strftime("%Y-%m-%d")
    past_start = past_start.strftime("%Y-%m-%d")
    past_end = past_end.strftime("%Y-%m-%d")

    async with httpx.AsyncClient() as client:

        token = await get_token(client)

        recent_data = await get_ndvi(
            client,
            req.bbox,
            recent_start,
            recent_end,
            token,
        )

        past_data = await get_ndvi(
            client,
            req.bbox,
            past_start,
            past_end,
            token,
        )

    recent_ndvi = read_ndvi(recent_data)
    past_ndvi = read_ndvi(past_data)

    alerts = find_deforestation(
        recent_ndvi,
        past_ndvi,
        req.bbox,
    )

    return {
        "alerts": alerts,
        "recentPeriod": f"{recent_start} to {recent_end}",
        "pastPeriod": f"{past_start} to {past_end}",
    }