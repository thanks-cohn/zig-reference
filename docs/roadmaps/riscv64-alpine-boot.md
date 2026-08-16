# RISC-V 64 Alpine Boot Roadmap

## Goal

Boot an unmodified Alpine Linux `riscv64` kernel and initramfs as a VS-mode guest under a Zig hypervisor, reach a serial console, and obtain an Alpine shell.

For the first successful boot, bypass U-Boot, GRUB, networking, and persistent installation. Load the Linux kernel, initramfs, and device tree directly.

The hypervisor runs in RISC-V HS-mode. Alpine Linux runs unmodified in VS-mode. The H extension supplies two-stage translation and the `hgatp` register used to translate guest physical addresses into host physical addresses.

## Foundation gate

Before machine-facing work begins:

- Zig 0.14.0 remains the baseline;
- all 39 unit tests pass;
- all 39 smoke tests pass;
- all recipes pass;
- all configured conformance checks pass;
- no compiled or opaque binary artifact is committed.

## Phase 1: RISC-V architectural vocabulary

39. `riscv-integer-register`
40. `riscv-privilege-mode`
41. `riscv-csr-address`
42. `riscv-cause-code`
43. `riscv-trap-value`
44. `riscv-status-register-fields`
45. `riscv-instruction-width`
46. `riscv-instruction-address`
47. `riscv-fence-kind`
48. `riscv-sbi-extension-id`

Gate A requires architectural fields to round-trip, reserved encodings to be rejected, unknown future values to be preserved where appropriate, and all modules to remain host-testable without inline assembly.

## Phase 2: Sv39 host-address translation primitives

49. `riscv-sv39-page-table-entry`
50. `riscv-sv39-virtual-address`
51. `riscv-sv39-page-table-index`
52. `riscv-sv39-level`
53. `riscv-sv39-satp`
54. `page-table-page`
55. `page-table-allocation`
56. `page-table-walk-result`
57. `sv39-page-table-walker`
58. `page-mapping-permissions`
59. `page-mapping-request`
60. `page-mapping-plan`
61. `sv39-page-table-editor`
62. `address-space-root`
63. `translation-fence-request`

Gate B requires 4 KiB, 2 MiB, and 1 GiB mapping and walking, malformed and misaligned mapping rejection, unmapping, deliberate replacement, and correct fence requests.

## Phase 3: Guest physical translation

64. `guest-physical-address`
65. `supervisor-physical-address`
66. `riscv-sv39x4-guest-physical-address`
67. `riscv-sv39x4-root-table`
68. `riscv-sv39x4-page-table-entry`
69. `riscv-hgatp`
70. `guest-stage-walk-result`
71. `sv39x4-page-table-walker`
72. `guest-memory-region`
73. `guest-memory-map`
74. `guest-stage-mapping-plan`
75. `guest-stage-page-table-editor`
76. `guest-memory-access`

Gate C requires isolated guest RAM, unmapped GPA faults, MMIO separation, atomic cross-region failure, and proof that guest mappings cannot reach hypervisor memory.

## Phase 4: Firmware boundary and HS-mode runtime

77. `riscv-csr-access`
78. `riscv-hypervisor-fence`
79. `riscv-sbi-call`
80. `sbi-base-client`
81. `sbi-timer-client`
82. `sbi-system-reset-client`
83. `sbi-hart-state-client`
84. `early-console`
85. `riscv-boot-hart-context`
86. `riscv-hs-entry`
87. `freestanding-panic`
88. `physical-memory-bootstrap`

Gate D is reached when Hyper-Zig boots under QEMU `virt` through OpenSBI, prints platform diagnostics, and shuts down cleanly.

## Phase 5: Device-tree understanding

89. `fdt-header`
90. `fdt-token`
91. `fdt-string-table`
92. `fdt-property`
93. `fdt-node-path`
94. `fdt-reader`
95. `fdt-reg-decoder`
96. `fdt-interrupt-decoder`
97. `riscv-platform-description`
98. `fdt-builder`
99. `guest-device-tree-model`
100. `guest-device-tree-builder`

Gate E requires parsing a known QEMU `virt` DTB, extracting RAM/UART/interrupt/Virtio data, building a guest DTB, parsing it back, and rejecting malformed input.

## Phase 6: Trap and interrupt foundation

101. `riscv-trap-frame`
102. `riscv-trap-vector`
103. `riscv-hypervisor-trap-cause`
104. `guest-exit`
105. `guest-register-file`
106. `guest-program-counter`
107. `riscv-trapped-instruction`
108. `riscv-mmio-access`
109. `hypervisor-trap-dispatch`
110. `virtual-interrupt-state`
111. `virtual-timer-state`

Gate F is reached when a tiny VS-mode guest traps to HS-mode, receives a response, resumes, and shuts down.

## Phase 7: Guest SBI implementation

112. `guest-sbi-request`
113. `guest-sbi-response`
114. `guest-sbi-base`
115. `guest-sbi-timer`
116. `guest-sbi-ipi`
117. `guest-sbi-hart-state`
118. `guest-sbi-system-reset`
119. `guest-sbi-debug-console`
120. `guest-sbi-dispatch`

Gate G requires a synthetic guest to probe SBI, set a timer, receive a virtual timer interrupt, print, and shut down.

## Phase 8: Minimal virtual platform

121. `virtual-machine-configuration`
122. `virtual-cpu-state`
123. `virtual-machine-state`
124. `mmio-region`
125. `mmio-bus`
126. `virtual-uart-16550`
127. `host-console-bridge`
128. `virtual-interrupt-controller-interface`
129. `riscv-virtual-plic`
130. `riscv-virtual-aclint-or-timer`
131. `virtual-device-set`

Gate H requires the synthetic guest to print through the same emulated UART Linux will use.

## Phase 9: Linux image loading

132. `linux-riscv-image-header`
133. `linux-kernel-image`
134. `initramfs-image`
135. `guest-image-placement`
136. `guest-image-loader`
137. `linux-command-line`
138. `linux-riscv-boot-state`
139. `alpine-direct-boot-bundle`
140. `virtual-machine-launch-plan`

The direct boot state must set the Linux entry PC, guest hart ID in `a0`, guest DTB address in `a1`, and `satp = 0`. Alpine kernel and initramfs binaries remain external and are never committed to `zig-reference`.

## Phase 10: First Alpine boot

141. `hyper-zig-run-loop`
142. `guest-fault-diagnostics`
143. `alpine-boot-observer`
144. `alpine-boot-integration-test`

## First cathedral milestone

The milestone is complete when:

1. Hyper-Zig starts under QEMU/OpenSBI.
2. It detects the RISC-V H extension.
3. It allocates isolated guest RAM.
4. It builds Sv39x4 mappings.
5. It installs a guest DTB.
6. It loads an Alpine Linux kernel and initramfs.
7. It enters Linux in VS-mode.
8. It services guest SBI calls.
9. It handles timer interrupts.
10. It emulates the serial UART.
11. Linux initializes.
12. Alpine starts from initramfs.
13. A serial Alpine shell appears.

At this point, an unmodified Alpine Linux userspace is executing under an original Zig RISC-V hypervisor.

## Do not build before the first shell

Postpone SMP, networking, Virtio block/net, PCI, UEFI, GRUB, U-Boot emulation, migration, snapshots, nested virtualization, graphics, USB, IOMMU, the native Alpz kernel, musl, `apk-tools`, and package rebuilding.

## Immediately after Alpine boots

145. `virtual-uart-receive-fifo`
146. `virtual-uart-interrupt-delivery`
147. `virtio-mmio-transport`
148. `virtqueue-descriptor-chain-parser`
149. `virtio-block-device`
150. `raw-guest-disk-backend`
151. `persistent-vm-configuration`
152. `alpine-installed-disk-boot-test`
153. `virtio-network-device`
154. `host-packet-backend`
155. `guest-dhcp-connectivity-test`
156. `alpine-apk-connectivity-test`
157. `ssh-boot-integration-test`

The follow-on milestone is Alpine booting from disk with `apk`, networking, and SSH working.

## Dependency spine

```text
zig-reference repaired
    ↓
RISC-V architectural types
    ↓
Sv39 PTE and address types
    ↓
host page-table construction
    ↓
guest physical address types
    ↓
Sv39x4 and hgatp
    ↓
guest RAM isolation
    ↓
HS-mode entry and SBI client
    ↓
device-tree parser and builder
    ↓
trap entry and guest exits
    ↓
guest SBI implementation
    ↓
virtual timer and interrupt controller
    ↓
virtual serial UART
    ↓
Linux image loader
    ↓
Alpine kernel and initramfs
    ↓
VS-mode entry
    ↓
serial Alpine shell
```

## Scale at first boot

- 39 existing foundation modules;
- 106 proposed modules through the first Alpine shell;
- approximately 145 total modules at the first boot milestone.

Many modules should remain small, exact, independently testable, and contract-driven. The first Alpine shell is not the summit. It is the moment the cathedral supports weight.
