import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { fileURLToPath, URL } from 'node:url'

// dev 下监听作品文件夹的文件增删，自动失效 useContent 聚合模块并触发整页刷新。
// 背景：Vite 5 的 import.meta.glob 只监听「转换时已存在的文件」，向 data/works/<id>/
// 新增（或删除）媒体文件不会自动重扫，需手动 touch meta.json 或重启 dev server。
// 本插件补齐该缺口，使「往作品文件夹丢文件即生效」在 dev 与 build 行为一致。
function worksDataWatcher() {
  const MARKER = 'useContent.js'
  return {
    name: 'works-data-watcher',
    configureServer(server) {
      const isInWorks = (f) => f.replaceAll('\\', '/').includes('/data/works/')
      const invalidate = (f) => {
        if (!isInWorks(f)) return
        for (const [, mod] of server.moduleGraph.idToModuleMap) {
          if (mod.file && mod.file.replaceAll('\\', '/').endsWith(MARKER)) {
            server.moduleGraph.invalidateModule(mod)
            server.ws.send({ type: 'full-reload' })
            break
          }
        }
      }
      server.watcher.on('add', invalidate)
      server.watcher.on('unlink', invalidate)
    },
  }
}

// GitHub Pages 部署路径：按「用户页」部署，仓库名为「<你的GitHub用户名>.github.io」，
// 站点挂在根路径，因此 base 设为 '/'。若改为「项目页」部署，请把 base 改回 '/<仓库名>/'。
export default defineConfig({
  base: '/',
  plugins: [vue(), worksDataWatcher()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  // 作品文件夹内的脚本等非常规后缀文件（如 .sh）也作为静态资源发出，
  // 供 import.meta.glob(... query:'?url') 在构建期解析为资源 URL。
  assetsInclude: [/\.sh$/],
  // 关闭自动清空输出目录：避免构建时触发安全删除包装层（genie-trash）超时。
  // 改由下方 prebuild 脚本手动按需清理 dist。
  build: {
    emptyOutDir: false,
    // 作品文件夹内的脚本（.sh）等不内联，始终作为独立资源 URL 发出；
    // 其余资源沿用 Vite 默认：≤ 4096 字节内联，更大的（如视频）作为独立文件发出。
    // 注意：该回调需返回布尔值（true=内联 / false=不内联），
    // 返回数字会被当作 truthy 而误把大文件内联进 JS。
    assetsInlineLimit: (filePath, content) => {
      if (/\.sh$/.test(filePath)) return false
      return content.length <= 4096
    },
  },
  server: {
    port: 5173,
    open: false,
  },
})
