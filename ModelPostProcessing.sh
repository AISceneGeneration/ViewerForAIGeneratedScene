echo "Start Processing Scene Model"

export INPUT_FILE=./public/GeneratedScene/SampleScene.glb
export OUTPUT_FILE=./public/GeneratedScene/Optimized_Scene.glb

# The glb file exported from Unity is located at ./public/GeneratedScene/SampleScene.glb

# In the demo, SampleScene.glb is approximately 179MB,
# after processing, Optimized_Scene.glb is approximately 30MB
# with the help of mod_deflate in Apache, the size of the file transferred to the client is approximately 18.6MB

### DEDUPLICATE ###
# Deduplicate accessors, textures, materials, meshes, and skins. Some exporters or
# pipeline processing may lead to multiple resources within a file containing
# redundant copies of the same information. This functions scans for these cases
# and merges the duplicates where possible, reducing file size. The process may
# be very slow on large files with many accessors.

# Deduplication early in a pipeline may also help other optimizations, like
# compression and instancing, to be more effective.
echo "[0] Deduplicate"
gltf-transform dedup $INPUT_FILE ./public/GeneratedScene/0_dedup.glb

### SIMPLIFY ### // This is too radical, will cause the model to lose too much detail, but it does shrink the file size remarkably
# Simplify mesh, reducing number of vertices.
# Simplification algorithm producing meshes with fewer triangles and
# vertices. Simplification is lossy, but the algorithm aims to
# preserve visual quality as much as possible, for given parameters.

# The algorithm aims to reach the target --ratio, while minimizing error. If
# error exceeds the specified --error threshold, the algorithm will quit
# before reaching the target ratio. Examples:

# - ratio=0.5, error=0.001: Aims for 50% simplification, constrained to 0.1% error.
# - ratio=0.5, error=1: Aims for 50% simplification, unconstrained by error.
# - ratio=0.0, error=0.01: Aims for maximum simplification, constrained to 1% error.

# Topology, particularly split vertices, will also limit the simplifier. For
# best results, apply a 'weld' operation before simplification.

# Based on the meshoptimizer library (https://github.com/zeux/meshoptimizer).

# echo "[1] Simplify"
# gltf-transform simplify ./public/GeneratedScene/0_dedup.glb ./public/GeneratedScene/1_simplify.glb --ratio 0.8 --error 0.001

### MATERIAL ###
# Convert the material to metalrough for better compatibility
# Metalrough: Convert materials from spec/gloss to metal/rough. In general, the metal/rough
# workflow is better supported, more compact, and more future-proof. All features
# of the spec/gloss workflow can be converted to metal/rough, as long as the
# KHR_materials_specular and KHR_materials_ior extensions are supported. When one
# or both of those extensions are not supported, metallic materials may require
# further adjustments after the conversion.

# This conversion rewrites spec/gloss textures, and the resulting textures may
# have less optimal compression than the original. Ideally, lossless PNG textures
# should be used as input, and then compressed after this conversion
echo "[1] Convert Material to MetalRough"
gltf-transform metalrough ./public/GeneratedScene/0_dedup.glb ./public/GeneratedScene/1_material_metalrough.glb

### REGENERATE TANGENTS ###
# Generates MikkTSpace vertex tangents.

# In some situations normal maps may appear incorrectly, displaying hard edges
# at seams, or unexpectedly inverted insets and extrusions. The issue is most
# commonly caused by a mismatch between the software used to bake the normal map
# and the pixel shader or other code used to render it. While this may be a
# frustration to an artist/designer, it is not always possible for the rendering
# engine to reconstruct the tangent space used by the authoring software.

# Most normal map bakers use the MikkTSpace standard (http://www.mikktspace.com/)
# to generate vertex tangents while creating a normal map, and the technique is
# recommended by the glTF 2.0 specification. Generating vertex tangents with this
# tool may resolve rendering issues related to normal maps in engines that cannot
# compute MikkTSpace tangents at runtime.

echo "[2] Regenerate tangents"
gltf-transform tangents ./public/GeneratedScene/1_material_metalrough.glb ./public/GeneratedScene/2_tangent.glb --overwrite true

### TEXTURE ###
# Compress the texture to reduce overall glb size
# Already resized all texture to 128x128 when exporting from Unity, so no need to resize here
# WebP: Compresses textures with WebP, using sharp. Reduces transmitted file
# size. Compared to GPU texture compression like KTX/Basis, PNG/JPEG/WebP must
# be fully decompressed in GPU memory — this makes texture GPU upload much
# slower, and may consume 4-8x more GPU memory. However, the PNG/JPEG/WebP
# compression methods are typically more forgiving than GPU texture compression,
# and require less tuning to achieve good visual and filesize results.
echo "[3] Compress Texture with WebP"
gltf-transform webp ./public/GeneratedScene/2_tangent.glb ./public/GeneratedScene/3_texture_webp.glb

### ANIMATION ###
# Try to optimize storage with sparse data storage,
# Sparse: Scans all Accessors in the Document, detecting whether each Accessor would
# benefit from sparse data storage. Currently, sparse data storage is used only
# when many values (≥ 1/3) are zeroes. Particularly for assets using morph
# target ("shape key") animation, sparse data storage may significantly reduce
# file sizes.
echo "[4] Optimize Animation with Sparse Data Storage"
gltf-transform sparse ./public/GeneratedScene/3_texture_webp.glb ./public/GeneratedScene/4_animation_sparse.glb

### GEOEMTRY ###
# Weld: Index geometry and optionally merge similar vertices. When merged and indexed,
# data is shared more efficiently between vertices. File size can be reduced, and
# the GPU can sometimes use the vertex cache more efficiently.

# When welding, the --tolerance threshold determines which vertices qualify for
# welding based on distance between the vertices as a fraction of the primitive's
# bounding box (AABB). For example, --tolerance=0.01 welds vertices within +/-1%
# of the AABB's longest dimension. Other vertex attributes are also compared
# during welding, with attribute-specific thresholds. For --tolerance=0, geometry
# is indexed in place, without merging.
echo "[5] Optimize Geometry with Weld"
gltf-transform weld ./public/GeneratedScene/4_animation_sparse.glb ./public/GeneratedScene/5_geometry_weld.glb --tolerance=0

#Instance: For meshes reused by more than one node in a scene, this command creates an
# EXT_mesh_gpu_instancing extension to aid with GPU instancing. In engines that
# support the extension, this may allow GPU instancing to be used, reducing draw
# calls and improving framerate.

# Engines may use GPU instancing with or without the presence of this extension,
# and are strongly encouraged to do so. However, particularly when loading a
# model at runtime, the extension provides useful context allowing the engine to
# use this technique efficiently.

# Instanced meshes cannot be animated, and must share the same materials. For
# further details, see:

# https://github.com/KhronosGroup/glTF/tree/master/extensions/2.0/Vendor/EXT_mesh_gpu_instancing.
echo "[6] Optimize Geometry with GPU instancing"
gltf-transform instance ./public/GeneratedScene/5_geometry_weld.glb ./public/GeneratedScene/6_geometry_instance.glb

# Reorder: Optimize vertex data for locality of reference.
# Choose whether the order should be optimal for transmission size (recommended for Web) or for GPU
# rendering performance. When optimizing for transmission size, reordering is expected to be a pre-
# processing step before applying Meshopt compression and lossless supercompression (such as gzip or
# brotli). Reordering will only reduce size when used in combination with other compression methods.
# Based on the meshoptimizer library (https://github.com/zeux/meshoptimizer).
echo "[7] Optimize Geometry with Reorder"
gltf-transform reorder ./public/GeneratedScene/6_geometry_instance.glb ./public/GeneratedScene/7_geometry_reorder.glb

# Prune: Removes properties from the file if they are not referenced by a Scene. 
# Helpful when cleaning up after complex workflows or a faulty exporter. This function
# may (conservatively) fail to identify some unused extension properties, such as
# lights, but it will not remove anything that is still in use, even if used by
# an extension. Animations are considered unused if they do not target any nodes
# that are children of a scene.
echo "[8] Prune Unused Data"
gltf-transform prune ./public/GeneratedScene/7_geometry_reorder.glb ./public/GeneratedScene/8_prune.glb

# Meshopt: Compress geometry, morph targets, and animation with Meshopt. Meshopt
# compression decodes very quickly, and is best used in combination with a
# lossless compression method like brotli or gzip.

# Compresses
# - geometry (points, lines, triangle meshes)
# - morph targets
# - animation tracks

# Documentation
# - https://gltf-transform.donmccurdy.com/classes/extensions.meshoptcompression.html

# References
# - meshoptimizer: https://github.com/zeux/meshoptimizer
# - EXT_meshopt_compression: https://github.com/KhronosGroup/gltf/blob/main/extensions/2.0/Vendor/EXT_meshopt_compression/
echo "[9] Compress Geometry with Meshopt"
gltf-transform meshopt ./public/GeneratedScene/8_prune.glb $OUTPUT_FILE

# Remove all intermediate files
echo "[8] Remove Intermediate Files"
rm ./public/GeneratedScene/0_dedup.glb
# rm ./public/GeneratedScene/1_simplify.glb
rm ./public/GeneratedScene/1_material_metalrough.glb
rm ./public/GeneratedScene/2_tangent.glb
rm ./public/GeneratedScene/3_texture_webp.glb
rm ./public/GeneratedScene/4_animation_sparse.glb
rm ./public/GeneratedScene/5_geometry_weld.glb
rm ./public/GeneratedScene/6_geometry_instance.glb
rm ./public/GeneratedScene/7_geometry_reorder.glb
rm ./public/GeneratedScene/8_prune.glb

# Done
echo "Finish Processing Scene Model, final model is located at $OUTPUT_FILE"
