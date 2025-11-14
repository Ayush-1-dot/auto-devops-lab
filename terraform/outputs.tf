output "sandbox_public_ip" {
  description = "Public IP of the Auto DevOps sandbox EC2 instance"
  value       = aws_eip.sandbox_ip.public_ip
}

output "sandbox_ssh" {
  description = "SSH connection string (if key_name was provided)"
  value       = var.key_name != "" ? "ssh -i <path-to-key.pem> ubuntu@${aws_eip.sandbox_ip.public_ip}" : "ssh ubuntu@${aws_eip.sandbox_ip.public_ip}"
}

output "urls" {
  description = "Common service URLs (Nginx, Grafana, Prometheus, Jenkins)"
  value = {
    nginx      = "http://${aws_eip.sandbox_ip.public_ip}/"
    sample_app = "http://${aws_eip.sandbox_ip.public_ip}:5000/"
    grafana    = "http://${aws_eip.sandbox_ip.public_ip}:3000/"
    prometheus = "http://${aws_eip.sandbox_ip.public_ip}:9090/"
    jenkins    = "http://${aws_eip.sandbox_ip.public_ip}:8080/"
  }
}
