# glTF Viewer

Preview glTF 2.0 models in WebGL using three.js and a drag-and-drop interface.

Viewer: [gltf-viewer.donmccurdy.com](https://gltf-viewer.donmccurdy.com/)

This fork is tailored for lightweight 3D Scenes exported from AISceneGeneration tool.  
A 3D model lightweight pipeline is implemented in https://github.com/AISceneGeneration/ViewerForAIGeneratedScene/blob/main/ModelPostProcessing.sh  
You can run it with bash. Be sure you set the `INPUT_FILE` and `OUTPUT_FILE` correctly before running.  
gltf-transform cinnabd-line tool is required for the pipeline. You can get it easily through npm:`npm install --global @gltf-transform/cli`


## Quickstart

```
npm install
npm run dev
```

## glTF 2.0 Resources

- [THREE.GLTFLoader](https://threejs.org/docs/#examples/en/loaders/GLTFLoader)
- [glTF 2.0 Specification](https://github.com/KhronosGroup/glTF/blob/master/specification/2.0/README.md)
- [glTF 2.0 Sample Models](https://github.com/KhronosGroup/glTF-Sample-Models/tree/master/2.0/)
