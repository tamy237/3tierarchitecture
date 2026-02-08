output "frontend_public_ip" {
  value = aws_instance.ec2_frontend.public_ip
}
output "backend_private_ip" {
  value = aws_instance.ec2_backend.public_ip
}