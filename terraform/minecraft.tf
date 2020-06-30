# Turn on Compute API to provision VMs
resource "google_project_service" "compute" {
  service = "compute.googleapis.com"
}

oogle_project_service.compute: Creating...
google_project_iam_custom_role.instanceLister: Creating...
google_compute_address.minecraft: Creating...
google_compute_network.minecraft: Creating...
google_project_iam_custom_role.minecraftSwitcher: Creating...
google_compute_disk.minecraft: Creating...
google_service_account.minecraft: Creating...

# Create service account to run service with no permissions
resource "google_service_account" "minecraft" {
  account_id   = "minecraft"
  display_name = "minecraft"
}

# Permenant Minecraft disk, stays around when VM is off
resource "google_compute_disk" "minecraft" {
  name  = "mc-${var.application}-${var.zone}"
  type  = "pd-standard"
  zone  = var.zone
  image = "cos-cloud/cos-stable"
  depends_on = [google_project_service.compute]
}

# Permenant IP address, stays around when VM is off
resource "google_compute_address" "minecraft" {
  name   = "mc-${substr("${var.application}-${var.zone}", 0, 64)}"
  region = var.region
  depends_on = [google_project_service.compute]
}

# VM to run Minecraft, we use preemptable which will shutdown within 24 hours
resource "google_compute_instance" "minecraft" {
  name         = "mc-${var.application}-${var.zone}"
  machine_type = "n1-standard-1"
  zone         = var.zone
  tags         = ["minecraft"]

  # Run itzg/minecraft-server docker image on startup
  # The instructions of https://hub.docker.com/r/itzg/minecraft-server/ are applicable
  # For instance, Ssh into the instance and you can run
  #  docker logs mc
  #  docker exec -i mc rcon-cli
  # Once in rcon-cli you can "op <player_id>" to make someone an operator (admin)
  # Use 'sudo journalctl -u google-startup-scripts.service' to retrieve the startup script output
  metadata_startup_script = var.startup_script

  boot_disk {
    auto_delete = false # Keep disk after shutdown (game data)
    source      = google_compute_disk.minecraft.self_link
  }

  network_interface {
    subnetwork = google_compute_subnetwork.minecraft.name
    access_config {
      nat_ip = google_compute_address.minecraft.address
    }
  }

  service_account {
    email  = google_service_account.minecraft.email
    scopes = ["userinfo-email"]
  }

  scheduling {
    preemptible       = true # Closes within 24 hours (sometimes sooner)
    automatic_restart = false
  }
}

# Create a private network so the minecraft instance cannot access
# any other resources.
resource "google_compute_network" "minecraft" {
  name = "minecraft${var.application}"
  auto_create_subnetworks = false
  depends_on = [google_project_service.compute]
}

resource "google_compute_subnetwork" "minecraft" {
  name          = "minecraft-${var.application}-${var.region}"
  ip_cidr_range = "10.0.0.0/16"
  region        = var.region
  network       = google_compute_network.minecraft.id
}

# Open the firewall for Minecraft traffic
resource "google_compute_firewall" "minecraft" {
  name    = "minecraft"
  network = google_compute_network.minecraft.name
  # Minecraft client port
  allow {
    protocol = "tcp"
    ports    = ["25565"]
  }
  # ICMP (ping)
  allow {
    protocol = "icmp"
  }
  # SSH (for RCON-CLI access)
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["minecraft"]
}

resource "google_project_iam_custom_role" "minecraftSwitcher" {
  role_id     = "MinecraftSwitcher"
  title       = "Minecraft Switcher"
  description = "Can turn a VM on and off"
  permissions = ["compute.instances.start", "compute.instances.stop", "compute.instances.get"]
}

resource "google_project_iam_custom_role" "instanceLister" {
  role_id     = "InstanceLister"
  title       = "Instance Lister"
  description = "Can list VMs in project"
  permissions = ["compute.instances.list"]
}

resource "google_compute_instance_iam_member" "switcher" {
  count = var.enable_switch_access_group
  project = var.project
  zone = var.zone
  instance_name = google_compute_instance.minecraft.name
  role = google_project_iam_custom_role.minecraftSwitcher.id
  member = "group:${var.minecraft_switch_access_group}"
}

resource "google_project_iam_member" "projectBrowsers" {
  count = var.enable_switch_access_group
  project = var.project
  role    = "roles/browser"
  member  = "group:${var.minecraft_switch_access_group}"
}

resource "google_project_iam_member" "computeViewer" {
  count = var.enable_switch_access_group
  project = var.project
  role    = google_project_iam_custom_role.instanceLister.id
  member  = "group:${var.minecraft_switch_access_group}"
}
