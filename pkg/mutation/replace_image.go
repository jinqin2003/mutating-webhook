package mutation

import (
	"os"
	s "strings"

	"github.com/sirupsen/logrus"
	corev1 "k8s.io/api/core/v1"
)

// replaceImage is a container for the mutation replacing image registry
type replaceImage struct {
	Logger logrus.FieldLogger
}

// replaceImage implements the podMutator interface
var _ podMutator = (*replaceImage)(nil)

// Name returns the struct name
func (ri replaceImage) Name() string {
	return "replace_image"
}

// Mutate returns a new mutated pod according to set image registry
func (ri replaceImage) Mutate(pod *corev1.Pod) (*corev1.Pod, error) {
	ri.Logger = ri.Logger.WithField("mutation", ri.Name())
	mpod := pod.DeepCopy()

	sourceRegistry := os.Getenv("SOURCE_REGISTRY")
	targetRegistry := os.Getenv("TARGET_REGISTRY")

	for i, container := range mpod.Spec.initContainers {
		if s.Contains(container.Image, sourceRegistry) {
			image := s.Replace(container.Image, sourceRegistry, targetRegistry, 1)
			ri.Logger.Debugf("pod init container image %s is replaced to %s", container.Image, image)
			mpod.Spec.initContainers[i].Image = image
		}
	}

	for i, container := range mpod.Spec.Containers {
		if s.Contains(container.Image, sourceRegistry) {
			image := s.Replace(container.Image, sourceRegistry, targetRegistry, 1)
			ri.Logger.Debugf("pod image %s is replaced to %s", container.Image, image)
			mpod.Spec.Containers[i].Image = image
		}
	}

	return mpod, nil
}
