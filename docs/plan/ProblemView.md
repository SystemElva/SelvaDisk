# Problem View | SelvaDisk

The problem *SelvaDisk* tries to  solve is that of disk image creation
being a largely but dull manual process that can be automated with the
correct tools. *SelvaDisk* tries to be that tool.

## Target Audience

The target audience of this program  consists of developers of (mostly
hobbyist-grade) operating systems  and bootloaders. This audience most
likely doesn't  want to write shell scripts which  require maintenance
in the case of a breaking change in a dependency's API.

## Solution

SelvaDisk tries to solve the problem by using one format based on JSON
that defines a disk's layout in a  format equally readable by machines
as by humans.

The format is based on JSON because it is easy to write by humans, has
good checking software and is clearly standardized and deterministic,
with almost no loosely defined behavior, unlike XML. Furthermore, most
programmers of the target audience know JSON.

## Notes

- **Format Focus**  
    The focus of optimization  in the interaction with the program has
    to be kept on the definition format; i.e. the definition format is
    the preferred way to interact with SelvaDisk.

- **Breaking Changes**  
    There should  be no breaking  changes; the  extension API  and the
    image definition should be backwards-compatible in all versions.
    To achieve this, every part of the extension API as well as every
    file in the JSON format should specify its format-version.

- **Competing Programs**  
    This program will combine parts  of other command line software in
    the domain of disk image creation into itself, namely:

    - **`fdisk`**  
        Used for partitioning disks manually. Only useful for creating
        and modifying partition tables.

    - **`mkfs.fat`**  
        Used for creating FAT12, FAT16 and FAT32 - filesystems.

    - **`xorriso` / `mkisofs`**  
        Used for creating  `.ISO` disk images.
