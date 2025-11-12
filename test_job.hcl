job "testing_docker_client" {
  type = "batch"
  node_pool = "docker"

  group "example" {
    task "run_test" {
      driver = "raw_exec"

      artifact {
        source = "https://raw.githubusercontent.com/holochain/wind-tunnel-runner/refs/heads/main/README.md"
      }

      config {
        command = "cat"
        args = [
          "${NOMAD_TASK_DIR}/README.md"
        ]
      }
    }
  }
}
