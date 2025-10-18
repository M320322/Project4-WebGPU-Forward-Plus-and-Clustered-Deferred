// TODO-2: implement the light clustering compute shader

// ------------------------------------
// Calculating cluster bounds:
// ------------------------------------
// For each cluster (X, Y, Z):
//     - Calculate the screen-space bounds for this cluster in 2D (XY).
//     - Calculate the depth bounds for this cluster in Z (near and far planes).
//     - Convert these screen and depth bounds into view-space coordinates.
//     - Store the computed bounding box (AABB) for the cluster.

// ------------------------------------
// Assigning lights to clusters:
// ------------------------------------
// For each cluster:
//     - Initialize a counter for the number of lights in this cluster.

//     For each light:
//         - Check if the light intersects with the cluster’s bounding box (AABB).
//         - If it does, add the light to the cluster's light list.
//         - Stop adding lights if the maximum number of lights is reached.

//     - Store the number of lights assigned to this cluster.

@group(0) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(0) @binding(1) var<storage, read> lightSet: LightSet;
@group(0) @binding(2) var<storage, read_write> clusterSet: ClusterSet;

fn cornerRayDir(ndcXY: vec2f) -> vec3f {
    let p = cameraUniforms.invProjMat * vec4f(ndcXY, 1.0, 1.0);
    let v = p.xyz / p.w;
    return v / v.z;
}

fn sphereAABBIntersection(center: vec3f, radius: f32, minBounds: vec3f, maxBounds: vec3f) -> bool {
    let closestPoint = clamp(center, minBounds, maxBounds);
    let distance = length(center - closestPoint);
    return distance <= radius;
}

@compute
@workgroup_size(${clusteringWorkgroupSize}, ${clusteringWorkgroupSize}, ${clusteringWorkgroupSize})
fn main(@builtin(global_invocation_id) globalId: vec3u) {
    let clusterX = globalId.x;
    let clusterY = globalId.y;
    let clusterZ = globalId.z;

    if (clusterX >= ${clusterWidth} || clusterY >= ${clusterHeight} || clusterZ >= ${clusterDepth}) {
        return;
    }

    let clusterIndex = clusterX + clusterY * ${clusterWidth} + clusterZ * ${clusterWidth} * ${clusterHeight};

    let minScreenX = f32(clusterX) / f32(${clusterWidth}) * cameraUniforms.screenWidth;
    let maxScreenX = f32(clusterX + 1u) / f32(${clusterWidth}) * cameraUniforms.screenWidth;
    let minScreenY = f32(clusterY) / f32(${clusterHeight}) * cameraUniforms.screenHeight;
    let maxScreenY = f32(clusterY + 1u) / f32(${clusterHeight}) * cameraUniforms.screenHeight;

    let minNdcXY = vec2f(
        minScreenX / cameraUniforms.screenWidth * 2.0 - 1.0,
        (1.0 - minScreenY / cameraUniforms.screenHeight) * 2.0 - 1.0
    );
    let maxNdcXY = vec2f(
        maxScreenX / cameraUniforms.screenWidth * 2.0 - 1.0,
        (1.0 - maxScreenY / cameraUniforms.screenHeight) * 2.0 - 1.0
    );

    let near = cameraUniforms.nearPlane;
    let far = cameraUniforms.farPlane;
    let nearDepth = near * pow(far / near, f32(clusterZ) / f32(${clusterDepth}));
    let farDepth = near * pow(far / near, f32(clusterZ + 1u) / f32(${clusterDepth}));

    let ray00 = cornerRayDir(vec2f(minNdcXY.x, minNdcXY.y));
    let ray10 = cornerRayDir(vec2f(maxNdcXY.x, minNdcXY.y));
    let ray01 = cornerRayDir(vec2f(minNdcXY.x, maxNdcXY.y));
    let ray11 = cornerRayDir(vec2f(maxNdcXY.x, maxNdcXY.y));

    let p00n = -ray00 * nearDepth;
    let p10n = -ray10 * nearDepth;
    let p01n = -ray01 * nearDepth;
    let p11n = -ray11 * nearDepth;

    let p00f = -ray00 * farDepth;
    let p10f = -ray10 * farDepth;
    let p01f = -ray01 * farDepth;
    let p11f = -ray11 * farDepth;

    let minBounds = min(min(min(p00n, p10n), min(p01n, p11n)), min(min(p00f, p10f), min(p01f, p11f)));
    let maxBounds = max(max(max(p00n, p10n), max(p01n, p11n)), max(max(p00f, p10f), max(p01f, p11f)));

    clusterSet.clusters[clusterIndex].minBounds = minBounds;
    clusterSet.clusters[clusterIndex].maxBounds = maxBounds;
    clusterSet.clusters[clusterIndex].lightCount = 0u;

    var lightCount = 0u;
    for (var lightIdx = 0u; lightIdx < lightSet.numLights; lightIdx++) {
        let light = lightSet.lights[lightIdx];
        let lightPosView = (cameraUniforms.viewMat * vec4f(light.pos, 1.0)).xyz;

        if (sphereAABBIntersection(lightPosView, ${lightRadius}, minBounds, maxBounds)) {
            clusterSet.clusters[clusterIndex].lightIndices[lightCount] = lightIdx;
            lightCount++;
        }

        if (lightCount >= ${maxLightsPerCluster}) {
            break;
        }
    }

    clusterSet.clusters[clusterIndex].lightCount = lightCount;
}
