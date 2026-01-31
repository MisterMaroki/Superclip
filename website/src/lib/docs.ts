import fs from "fs";
import path from "path";
import matter from "gray-matter";

const DOCS_DIR = path.join(process.cwd(), "src/content/docs");

export interface Doc {
  slug: string;
  title: string;
  description: string;
  category: string;
  order: number;
  content: string;
}

export interface DocCategory {
  category: string;
  docs: Doc[];
}

export function getAllDocs(): Doc[] {
  const files = fs.readdirSync(DOCS_DIR).filter((f) => f.endsWith(".mdx"));

  const docs = files.map((file) => {
    const slug = file.replace(/\.mdx$/, "");
    return getDocBySlug(slug);
  });

  return docs.sort((a, b) => a.order - b.order);
}

export function getDocBySlug(slug: string): Doc {
  const filePath = path.join(DOCS_DIR, `${slug}.mdx`);
  const raw = fs.readFileSync(filePath, "utf-8");
  const { data, content } = matter(raw);

  return {
    slug,
    title: data.title,
    description: data.description,
    category: data.category,
    order: data.order,
    content,
  };
}

export function getDocsByCategory(): DocCategory[] {
  const docs = getAllDocs();
  const categoryMap = new Map<string, Doc[]>();

  for (const doc of docs) {
    const existing = categoryMap.get(doc.category);
    if (existing) {
      existing.push(doc);
    } else {
      categoryMap.set(doc.category, [doc]);
    }
  }

  return Array.from(categoryMap.entries()).map(([category, docs]) => ({
    category,
    docs,
  }));
}
