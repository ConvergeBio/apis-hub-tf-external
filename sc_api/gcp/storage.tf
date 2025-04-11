resource "google_compute_disk" "disk_tf" {
  name = "${var.instance_name}-disk"
  size = var.disk_size
  zone = var.zone
  type = "pd-ssd"
}

resource "google_compute_attached_disk" "a_disk_tf" {
  disk     = google_compute_disk.disk_tf.id
  instance = google_compute_instance.vm_instance.id
}
