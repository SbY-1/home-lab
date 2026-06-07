# Build a Talos Image Factory schematic that bakes in the requested extensions.
resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = var.talos_extensions
      }
    }
  })
}

locals {
  # Uncompressed nocloud qcow2 disk image. qcow2 is a disk format the 'import'
  # content type accepts directly, so NO decompression is needed -> the VM disk
  # is created purely via the Proxmox API (disk.import_from), no SSH.
  talos_image_url = "https://factory.talos.dev/image/${talos_image_factory_schematic.this.id}/${var.talos_version}/nocloud-amd64.qcow2"
}

resource "proxmox_download_file" "talos" {
  content_type = "import"
  datastore_id = var.image_datastore
  node_name    = var.proxmox_node
  url          = local.talos_image_url
  file_name    = "talos-${var.talos_version}-nocloud-amd64.qcow2"
  overwrite    = false
}
