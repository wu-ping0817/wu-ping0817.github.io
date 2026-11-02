import profile from '../../data/profile.json'
import categories from '../../data/portfolio.categories.json'

/**
 * useContent：内容数据层（构建期静态化）的运行时访问入口。
 *
 * 作品数据按文件夹管理：每个作品对应一个文件夹 data/works/<id>/，
 * 其中 meta.json 为元数据（构建期被 import.meta.glob 扫描进 JS），
 * 同文件夹内的媒体文件（脚本 / 缩略图 / 视频 / 海报等）经 ?url 转成
 * 构建期资源 URL。展示层（Portfolio.vue 等）只消费
 * portfolio.items / portfolio.categories，无需改动。
 *
 * 新增作品：在 data/works/ 下新建 <id>/ 文件夹，放入 meta.json 与媒体文件即可，
 * 无需修改任何总表或组件。
 */

// 1) 每个作品：data/works/<id>/meta.json（构建期直接读入为 JS 对象）
const metaModules = import.meta.glob('../../data/works/*/meta.json', {
  eager: true,
  import: 'default',
})

// 2) 同文件夹内的媒体资源：构建期转成资源 URL（脚本 / 缩略图 / 视频 / 海报等）
const assetModules = import.meta.glob('../../data/works/**/*', {
  eager: true,
  query: '?url',
  import: 'default',
})

// 媒体字段：在 meta.json 中以「相对作品文件夹的文件名」书写（如 "script": "docker-install.sh"），
// 在聚合时解析为最终资源 URL；已是完整 URL（http(s):// 或 // 或 data:）则原样保留。
const MEDIA_KEYS = ['thumb', 'script', 'video', 'poster', 'cover', 'file']

// 建立 <id>/<相对路径> -> 资源URL 映射（跳过 meta.json 自身）
const assetMap = {}
for (const [path, url] of Object.entries(assetModules)) {
  // path 形如 ../../data/works/<id>/<rel...>
  const marker = '/data/works/'
  const i = path.indexOf(marker)
  if (i === -1) continue
  const rel = path.slice(i + marker.length)
  if (rel.endsWith('meta.json')) continue
  assetMap[rel] = url
}

// 3) 聚合为 items，并解析媒体字段为资源 URL
const items = Object.values(metaModules)
  .map((meta) => {
    const id = meta.id
    const resolved = { ...meta }
    for (const key of MEDIA_KEYS) {
      const v = resolved[key]
      if (typeof v !== 'string' || !v) continue
      if (/^(https?:)?\/\//.test(v) || v.startsWith('data:')) continue
      const url = assetMap[`${id}/${v}`]
      if (url) {
        resolved[key] = url
      } else {
        // 文件尚未放入作品文件夹：移除该媒体引用，
        // 展示层据字段是否存在决定按钮显隐（避免出现指向 404 的死按钮）
        delete resolved[key]
      }
    }
    return resolved
  })
  // 稳定排序：可选 order 字段优先，其次按 id
  .sort((a, b) => (a.order ?? 999) - (b.order ?? 999) || (a.id < b.id ? -1 : 1))

export function useContent() {
  return {
    profile,
    portfolio: { categories, items },
  }
}
