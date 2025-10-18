// TODO-3: implement the Clustered Deferred fullscreen fragment shader

// Similar to the Forward+ fragment shader, but with vertex information coming from the G-buffer instead.

@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;
@group(${bindGroup_scene}) @binding(3) var gBufferPosition: texture_2d<f32>;
@group(${bindGroup_scene}) @binding(4) var gBufferNormal: texture_2d<f32>;
@group(${bindGroup_scene}) @binding(5) var gBufferAlbedo: texture_2d<f32>;

struct FragmentInput
{
    @builtin(position) fragCoord: vec4f,
    @location(0) uv: vec2f
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    let texCoord = vec2i(floor(in.fragCoord.xy));
    
    let position = textureLoad(gBufferPosition, texCoord, 0).xyz;
    let normal = textureLoad(gBufferNormal, texCoord, 0).xyz;
    let albedo = textureLoad(gBufferAlbedo, texCoord, 0);

    let clusterX = u32(in.fragCoord.x / cameraUniforms.screenWidth * f32(${clusterWidth}));
    let clusterY = u32(in.fragCoord.y / cameraUniforms.screenHeight * f32(${clusterHeight}));
    
    let viewPos = (cameraUniforms.viewMat * vec4f(position, 1.0)).xyz;
    let viewDepth = -viewPos.z;
    let near = cameraUniforms.nearPlane;
    let far = cameraUniforms.farPlane;
    let clusterZ = u32(log(viewDepth / near) / log(far / near) * f32(${clusterDepth}));

    let clusterIndex = clusterX + clusterY * ${clusterWidth} + clusterZ * ${clusterWidth} * ${clusterHeight};

    let cluster = &clusterSet.clusters[clusterIndex];
    let numLights = (*cluster).lightCount;

    var totalLightContrib = vec3f(0, 0, 0);
    for (var i = 0u; i < numLights; i++) {
        let lightIdx = (*cluster).lightIndices[i];
        let light = lightSet.lights[lightIdx];
        totalLightContrib += calculateLightContrib(light, position, normalize(normal));
    }

    var finalColor = albedo.rgb * totalLightContrib;
    return vec4(finalColor, 1);
}
