/** 文本工具(纯函数,可被单测直接覆盖) */

/** CSV 字段转义:含逗号/引号/换行时加引号包裹,内部引号双写 */
export function csvField(v: string): string {
  const s: string = v ?? ''
  if (/[",\n\r]/.test(s)) {
    return `"${s.replace(/"/g, '""')}"`
  }
  return s
}
