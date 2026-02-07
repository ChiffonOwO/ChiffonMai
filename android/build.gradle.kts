allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// 注释掉自定义构建目录配置，使用默认构建目录以避免插件构建路径冲突
// val newBuildDir: Directory =
//     rootProject.layout.buildDirectory
//         .dir("../../build")
//         .get()
// rootProject.layout.buildDirectory.value(newBuildDir)

// subprojects {
//     val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
//     project.layout.buildDirectory.value(newSubprojectBuildDir)
// }

// 自定义构建目录（仍在D盘项目根目录下，避免跨磁盘）
// 最终路径：D:\flutterProjects\my_first_flutter_app\custom_build
// rootProject.layout.buildDirectory.set(rootProject.layout.projectDirectory.dir("custom_build"))

// subprojects {
//     // 子项目构建目录：D:\flutterProjects\my_first_flutter_app\custom_build\子项目名
//     project.layout.buildDirectory.set(rootProject.layout.buildDirectory.dir(project.name))
// }


tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}