variable "zone" {
  type     = string
}

variable "startup_script" {
  type    = string
  default = "docker run -d -p 25565:25565 -e EULA=TRUE -e VERSION=1.15.2 -v /var/minecraft:/data --name mc -e TYPE=FORGE -e MEMORY=2G --rm=true itzg/minecraft-server:latest;"
}

variable "enable_switch_access_group" {
  type    = number
  default = 0
}

variable "minecraft_switch_access_group" {
  type    = string
  default = ""
}
