
--------------------------------------------------
docs/api/endpoints.md
--------------------------------------------------
```markdown
# API Reference

Base URL: `https://anomaly.example.com`

## POST /api/v1/predict
**Request**
```json
{
  "samples": [
    {
      "metric": "cpu",
      "value": 0.85,
      "labels": {"pod": "frontend-xyz", "namespace": "prod"}
    }
  ]
}