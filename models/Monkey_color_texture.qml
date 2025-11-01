import QtQuick
import QtQuick3D

Node {
    id: node

    // Resources
    Texture {
        id: c__Users_pomai_Documents_Monkey_base_color_png_texture
        objectName: "C:\Users\pomai\Documents\Monkey_base_color.png"
        generateMipmaps: true
        mipFilter: Texture.Linear
        source: "maps/Monkey_base_color.png"
    }
    PrincipledMaterial {
        id: monkey_material
        objectName: "Monkey"
        baseColor: "#ffcccccc"
        baseColorMap: c__Users_pomai_Documents_Monkey_base_color_png_texture
        roughness: 0.5
    }

    // Nodes:
    Node {
        id: rootNode
        objectName: "RootNode"
        Model {
            id: suzanne
            objectName: "Suzanne"
            rotation: Qt.quaternion(1.94707e-07, 1, 0, 0)
            scale: Qt.vector3d(100, 100, 100)
            source: "meshes/suzanne_mesh.mesh"
            materials: [
                monkey_material
            ]
        }
    }

    // Animations:
}
