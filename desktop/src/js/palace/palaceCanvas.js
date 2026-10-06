// Medha Windows Desktop — 2D Spatial Memory Palace Engine
// 100% faithful port of MemoryPalaceView.swift
// Features infinite 2D canvas, sequential loci pathways, and cinematic spring Walk Mode

class PalaceCanvas {
    constructor(stageElement, worldElement, options = {}) {
        this.stage = stageElement;
        this.world = worldElement;
        this.store = options.store;

        // Camera Transform
        this.cameraX = 0;
        this.cameraY = 0;
        this.scale = 1.0;

        // Panning State
        this.isPanning = false;
        this.panStart = { x: 0, y: 0 };

        // Walk Mode State
        this.isWalkMode = false;
        this.currentStepIndex = 0;

        this.bindEvents();
    }

    bindEvents() {
        this.stage.addEventListener('mousedown', (e) => {
            if (e.target === this.stage || e.target === this.world) {
                this.isPanning = true;
                this.panStart = { x: e.clientX - this.cameraX, y: e.clientY - this.cameraY };
                this.stage.classList.add('panning');
            }
        });

        if (typeof window !== 'undefined') {
            window.addEventListener('mousemove', (e) => {
                if (this.isPanning) {
                    this.cameraX = e.clientX - this.panStart.x;
                    this.cameraY = e.clientY - this.panStart.y;
                    this.updateTransform();
                }
            });

            window.addEventListener('mouseup', () => {
                if (this.isPanning) {
                    this.isPanning = false;
                    this.stage.classList.remove('panning');
                }
            });
        }

        this.stage.addEventListener('wheel', (e) => {
            e.preventDefault();
            const zoomFactor = e.deltaY < 0 ? 1.08 : 0.92;
            const newScale = Math.min(3.0, Math.max(0.2, this.scale * zoomFactor));

            // Zoom toward mouse pointer
            const rect = this.stage.getBoundingClientRect();
            const mouseX = e.clientX - rect.left;
            const mouseY = e.clientY - rect.top;

            this.cameraX = mouseX - (mouseX - this.cameraX) * (newScale / this.scale);
            this.cameraY = mouseY - (mouseY - this.cameraY) * (newScale / this.scale);
            this.scale = newScale;

            this.updateTransform();
        });
    }

    updateTransform() {
        this.world.style.transform = `translate(${this.cameraX}px, ${this.cameraY}px) scale(${this.scale})`;
    }

    // Spring Camera Navigation for Walk Mode
    panToLocus(locus, targetPhoto) {
        if (!targetPhoto) return;
        const rect = this.stage.getBoundingClientRect();

        // Calculate absolute position of locus pin in world space
        const pinWorldX = targetPhoto.canvasX + (locus.normalizedX * targetPhoto.canvasWidth);
        const pinWorldY = targetPhoto.canvasY + (locus.normalizedY * targetPhoto.canvasHeight);

        // Center on screen
        const targetScale = 1.35;
        const targetCamX = (rect.width / 2) - (pinWorldX * targetScale);
        const targetCamY = (rect.height / 2) - (pinWorldY * targetScale);

        this.animateCameraTo(targetCamX, targetCamY, targetScale);
    }

    animateCameraTo(targetX, targetY, targetScale, duration = 450) {
        const startX = this.cameraX;
        const startY = this.cameraY;
        const startScale = this.scale;
        const startTime = performance.now();

        const easeOutSpring = (t) => {
            return 1 - Math.pow(1 - t, 3); // Smooth cubic ease out
        };

        const step = (now) => {
            const elapsed = now - startTime;
            const progress = Math.min(1.0, elapsed / duration);
            const ease = easeOutSpring(progress);

            this.cameraX = startX + (targetX - startX) * ease;
            this.cameraY = startY + (targetY - startY) * ease;
            this.scale = startScale + (targetScale - startScale) * ease;
            this.updateTransform();
            if (progress < 1.0) {
                raf(step);
            }
        };

        const raf = typeof requestAnimationFrame !== 'undefined'
            ? requestAnimationFrame
            : (cb) => setTimeout(() => cb(performance.now()), 16);

        raf(step);
    }

    startWalkMode(loci, photos) {
        if (!loci || loci.length === 0) return;
        this.isWalkMode = true;
        this.currentStepIndex = 0;
        this.walkToStep(0, loci, photos);
    }

    walkToStep(stepIdx, loci, photos) {
        if (stepIdx < 0 || stepIdx >= loci.length) return;
        this.currentStepIndex = stepIdx;
        const locus = loci[stepIdx];
        const photo = photos.find(p => p.id === locus.photoId) || photos[0];
        this.panToLocus(locus, photo);
    }

    nextWalkStep(loci, photos) {
        if (this.currentStepIndex < loci.length - 1) {
            this.walkToStep(this.currentStepIndex + 1, loci, photos);
            return true;
        }
        return false; // Walk completed
    }

    prevWalkStep(loci, photos) {
        if (this.currentStepIndex > 0) {
            this.walkToStep(this.currentStepIndex - 1, loci, photos);
            return true;
        }
        return false;
    }

    exitWalkMode() {
        this.isWalkMode = false;
    }
}

if (typeof module !== 'undefined') {
    module.exports = { PalaceCanvas };
}
