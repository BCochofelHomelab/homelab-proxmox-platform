stack {
  name        = "shared-fleet"
  description = "Fleet: integration packages, the Fleet Server host, the Elasticsearch output and Fleet Server's agent policy"
  tags        = ["elastic", "shared"]
  after       = ["/shared/data"]
  id          = "7d205fc1-ceb2-4713-b3aa-f4a1b3f3bd6f"
}
