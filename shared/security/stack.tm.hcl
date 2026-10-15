stack {
  name        = "shared-security"
  description = "Platform roles, service accounts, one API key per stack"
  id          = "2cf1fb30-6c14-5ca0-accd-6ab11bc33996"
  tags        = ["shared", "elasticstack"]
  after       = ["tag:platform"]
}
