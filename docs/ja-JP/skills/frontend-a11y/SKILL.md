---
name: frontend-a11y
description: React と Next.js 向けのアクセシビリティパターン。セマンティック HTML、ARIA 属性、フォームのラベル付け、キーボードナビゲーション、フォーカス管理、スクリーンリーダー対応を扱います。フォーム、モーダル、ドロップダウン、ツールチップ、タブの構築やレビュー、a11y の lint やコードレビューでの指摘の修正、キーボードナビゲーションやフォーカス管理の実装時に使用します。
metadata:
  origin: community
---

# フロントエンドアクセシビリティパターン

React と Next.js のための実践的なアクセシビリティパターンです。コードレビューで最も頻繁に指摘される問題を扱います。具体的には、フォームラベルの欠落、ARIA の誤用、非セマンティックなインタラクティブ要素、正しく機能しないキーボードナビゲーションです。

## 有効化するタイミング

- フォームコンポーネント（`<input>`、`<select>`、`<textarea>`）を構築またはレビューするとき
- インタラクティブな要素（モーダル、ドロップダウン、ツールチップ、タブ）を作成するとき
- `onClick` を持つ `<div>` や `<span>` を使っているとき
- 任意の要素に `aria-*` 属性を追加するとき
- キーボードナビゲーションやフォーカス管理を実装するとき
- コードレビューツール（CodeRabbit、ESLint a11y）からアクセシビリティに関するフィードバックを受け取ったとき
- スクリーンリーダーに対応する必要があるコンポーネントを構築するとき

## フォームのアクセシビリティ

`htmlFor` / `id` の組み合わせの欠落や、エラーメッセージが入力欄と結び付いていないことは、コードレビューで最も頻繁に指摘される問題です。

### ラベルの関連付け

```tsx
// BAD: label が input と関連付けられていない — スクリーンリーダーは両者を結び付けられない
<label>Email</label>
<input type="email" />

// GOOD: htmlFor が input の id と一致している
<label htmlFor="email">Email</label>
<input id="email" type="email" />
```

### 必須フィールド

```tsx
// BAD: 見た目だけのアスタリスクはスクリーンリーダーに何も伝えない
<label htmlFor="email">Email *</label>
<input id="email" type="email" />

// GOOD: required でブラウザ標準のバリデーションが有効になり、aria-required がスクリーンリーダーに伝える
<label htmlFor="email">
  Email <span aria-hidden="true">*</span>
</label>
<input id="email" type="email" required aria-required="true" />
```

### エラーメッセージ

```tsx
// BAD: エラーテキストは視覚的には存在するが、入力欄と結び付いていない
<input id="email" type="email" />
<span className="error">Invalid email address</span>

// GOOD: aria-describedby が入力欄とエラーメッセージを結び付ける
// aria-invalid が無効状態をスクリーンリーダーに伝える
<input
  id="email"
  type="email"
  aria-describedby="email-error"
  aria-invalid={!!error}
/>
{error && (
  <span id="email-error" role="alert">
    {error}
  </span>
)}
```

### アクセシブルなフォームの完全な例

```tsx
interface LoginFormProps {
  onSubmit: (email: string, password: string) => void;
}

export function LoginForm({ onSubmit }: LoginFormProps) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [errors, setErrors] = useState<{ email?: string; password?: string }>({});

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const newErrors: typeof errors = {};
    if (!email) newErrors.email = 'Email is required';
    if (!password) newErrors.password = 'Password is required';
    if (Object.keys(newErrors).length) {
      setErrors(newErrors);
      return;
    }
    onSubmit(email, password);
  };

  return (
    <form onSubmit={handleSubmit} noValidate>
      <div>
        <label htmlFor="email">
          Email <span aria-hidden="true">*</span>
        </label>
        <input
          id="email"
          type="email"
          value={email}
          onChange={e => setEmail(e.target.value)}
          aria-required="true"
          aria-describedby={errors.email ? 'email-error' : undefined}
          aria-invalid={!!errors.email}
          autoComplete="email"
        />
        {errors.email && (
          <span id="email-error" role="alert">
            {errors.email}
          </span>
        )}
      </div>

      <div>
        <label htmlFor="password">
          Password <span aria-hidden="true">*</span>
        </label>
        <input
          id="password"
          type="password"
          value={password}
          onChange={e => setPassword(e.target.value)}
          aria-required="true"
          aria-describedby={errors.password ? 'password-error' : undefined}
          aria-invalid={!!errors.password}
          autoComplete="current-password"
        />
        {errors.password && (
          <span id="password-error" role="alert">
            {errors.password}
          </span>
        )}
      </div>

      <button type="submit">Log in</button>
    </form>
  );
}
```

## セマンティック HTML

意図に合った要素を使用します。スクリーンリーダーやキーボードユーザーはネイティブのセマンティクスに依存しています。

```tsx
// BAD: div にはロールもキーボードサポートもアクセシブルな名前もない
<div onClick={handleClick}>Submit</div>

// GOOD: button はフォーカス可能で、Enter/Space で操作でき、「ボタン」として読み上げられる
<button type="button" onClick={handleClick}>Submit</button>
```

```tsx
// BAD: 非セマンティックなナビゲーション
<div onClick={() => navigate('/home')}>Home</div>

// GOOD: アンカーは右クリック、中クリック、キーボードナビゲーションに対応する
<a href="/home">Home</a>
```

```tsx
// BAD: 見出し階層が飛んでいる（h1 から h4）
<h1>Dashboard</h1>
<h4>Recent Activity</h4>

// GOOD: 見出しレベルが連続している
<h1>Dashboard</h1>
<h2>Recent Activity</h2>
```

## ARIA 属性

ARIA はネイティブ HTML のセマンティクスでは不十分な場合にのみ使用します。誤った ARIA は、ARIA がないことよりも悪い結果を招きます。

### aria-label と aria-labelledby

```tsx
// aria-label: インラインの文字列ラベル — 表示されるラベルテキストがない場合に使用する
<button aria-label="Close modal">
  <XIcon />
</button>

// aria-labelledby: 別の要素のテキストを参照する — 表示されるラベルがある場合に使用する
<section aria-labelledby="section-title">
  <h2 id="section-title">Recent Orders</h2>
  {/* content */}
</section>
```

### aria-describedby

```tsx
// ラベルを超える補足的な説明を提供する
<button
  aria-describedby="delete-warning"
  onClick={handleDelete}
> Delete account
</button>
<p id="delete-warning">This action cannot be undone.</p>
```

### 動的コンテンツのための aria-live

```tsx
// ページをリロードせずに更新されるコンテンツを通知するには aria-live を使用する
// polite: ユーザーが現在の操作を終えるまで待ってから通知する
// assertive: 即座に割り込む — 緊急のエラーにのみ使用する

export function StatusMessage({ message, isError }: { message: string; isError?: boolean }) {
  return (
    <div role="status" aria-live={isError ? 'assertive' : 'polite'} aria-atomic="true">
      {message}
    </div>
  );
}
```

### aria-expanded と aria-controls

```tsx
export function Accordion({ title, children }: { title: string; children: React.ReactNode }) {
  const [isOpen, setIsOpen] = useState(false);
  const contentId = useId();

  return (
    <div>
      <button aria-expanded={isOpen} aria-controls={contentId} onClick={() => setIsOpen(prev => !prev)}>
        {title}
      </button>
      <div id={contentId} hidden={!isOpen}>
        {children}
      </div>
    </div>
  );
}
```

## キーボードナビゲーション

すべてのインタラクティブな要素は、キーボードだけで到達でき、操作できなければなりません。

### カスタムドロップダウン

```tsx
export function Dropdown({ options, onSelect }: { options: string[]; onSelect: (value: string) => void }) {
  const [isOpen, setIsOpen] = useState(false);
  const [activeIndex, setActiveIndex] = useState(0);
  const listId = useId();

  if (!options.length) return null;

  const handleKeyDown = (e: React.KeyboardEvent) => {
    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault();
        setActiveIndex(i => Math.min(i + 1, options.length - 1));
        break;
      case 'ArrowUp':
        e.preventDefault();
        setActiveIndex(i => Math.max(i - 1, 0));
        break;
      case 'Enter':
      case ' ':
        e.preventDefault();
        if (isOpen) onSelect(options[activeIndex]);
        setIsOpen(prev => !prev);
        break;
      case 'Escape':
        setIsOpen(false);
        break;
    }
  };

  return (
    <div
      role="combobox"
      aria-expanded={isOpen}
      aria-haspopup="listbox"
      aria-controls={listId}
      tabIndex={0}
      onKeyDown={handleKeyDown}
      onClick={() => setIsOpen(prev => !prev)}
    >
      <span>{options[activeIndex]}</span>
      {isOpen && (
        <ul id={listId} role="listbox">
          {options.map((option, index) => (
            <li
              key={option}
              role="option"
              aria-selected={index === activeIndex}
              onClick={() => {
                onSelect(option);
                setIsOpen(false);
              }}
            >
              {option}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
```

## フォーカス管理

UI の状態が変化したときは、フォーカスも論理的に移動しなければなりません。特にモーダルやルート遷移で重要です。

### モーダルのフォーカス復元

> この例は初期フォーカスとその復元を扱います。完全なフォーカストラップ（モーダル内での Tab/Shift+Tab の循環）には、動的コンテンツやネストしたポータルなどのエッジケースを処理してくれる [`focus-trap-react`](https://github.com/focus-trap/focus-trap-react) のようなライブラリを使用してください。

```tsx
export function Modal({ isOpen, onClose, title, children }: { isOpen: boolean; onClose: () => void; title: string; children: React.ReactNode }) {
  const modalRef = useRef<HTMLDivElement>(null);
  const previousFocusRef = useRef<HTMLElement | null>(null);

  useEffect(() => {
    if (isOpen) {
      // 現在フォーカスされている要素を保存し、フォーカスをモーダル内に移動する
      previousFocusRef.current = document.activeElement as HTMLElement;
      modalRef.current?.focus();
    } else {
      // モーダルを開いた要素にフォーカスを戻す
      previousFocusRef.current?.focus();
    }
  }, [isOpen]);

  if (!isOpen) return null;

  return (
    <div ref={modalRef} role="dialog" aria-modal="true" aria-labelledby="modal-title" tabIndex={-1} onKeyDown={e => e.key === 'Escape' && onClose()}>
      <h2 id="modal-title">{title}</h2>
      {children}
      <button onClick={onClose}>Close</button>
    </div>
  );
}
```

## 画像とアイコン

```tsx
// BAD: 装飾アイコンがラベルのない画像として読み上げられる
<img src="/icon.svg" />

// GOOD: 装飾画像はスクリーンリーダーから隠す
<img src="/decoration.png" alt="" aria-hidden="true" />

// GOOD: 意味のある画像には説明的な alt テキストを付ける
<img src="/chart.png" alt="Monthly revenue increased 23% from January to March" />

// GOOD: アクセシブルなラベル付きのアイコンボタン
<button aria-label="Delete item">
  <TrashIcon aria-hidden="true" />
</button>
```

## モーションの低減

OS の設定でモーションの低減を要求しているユーザーを尊重します。

```tsx
export function useReducedMotion(): boolean {
  const [prefersReduced, setPrefersReduced] = useState(false);

  useEffect(() => {
    const mq = window.matchMedia('(prefers-reduced-motion: reduce)');
    setPrefersReduced(mq.matches);
    const handler = (e: MediaQueryListEvent) => setPrefersReduced(e.matches);
    mq.addEventListener('change', handler);
    return () => mq.removeEventListener('change', handler);
  }, []);

  return prefersReduced;
}

// 使用例
export function AnimatedCard({ children }: { children: React.ReactNode }) {
  const reduceMotion = useReducedMotion();

  return (
    <div
      style={{
        transition: reduceMotion ? 'none' : 'transform 300ms ease'
      }}
    >
      {children}
    </div>
  );
}
```

## アンチパターン

```tsx
// BAD: キーボードサポートのない非インタラクティブ要素への onClick
<div onClick={handleClick}>Click me</div>

// BAD: ロールのない div への aria-label
<div aria-label="Navigation">...</div>

// BAD: placeholder をラベルの代用にしている
<input placeholder="Enter your email" />

// BAD: 正の tabIndex は予測不能なタブ順序を生む
<button tabIndex={3}>Submit</button>

// BAD: フォーカス可能な要素への aria-hidden — キーボードユーザーが閉じ込められる
<button aria-hidden="true">Open</button>

// BAD: キーボードハンドラのない div への role="button"
<div role="button" onClick={handleClick}>Submit</div>
// 不足: tabIndex={0}、Enter/Space 用の onKeyDown
```

## チェックリスト

インタラクティブなコンポーネントをレビューに出す前に確認します。

- [ ] すべての `<input>`、`<select>`、`<textarea>` に、`htmlFor`/`id` で接続された `<label>` がある
- [ ] エラーメッセージが `aria-describedby` で結び付けられ、`role="alert"` が付いている
- [ ] `<div>` や `<span>` への `onClick` には、必ず `role`、`tabIndex`、`onKeyDown` が付いている
- [ ] アイコンのみのボタンに `aria-label` がある
- [ ] 装飾画像には `alt=""` と `aria-hidden="true"` を使用している
- [ ] モーダルは閉じるときにフォーカスを復元する（Tab/Shift+Tab の循環を含む完全なフォーカストラップには `focus-trap-react` のようなライブラリを使用する）
- [ ] 動的コンテンツの更新に `aria-live` を使用している
- [ ] アニメーションで `prefers-reduced-motion` が尊重されている

## 関連スキル

- `frontend-patterns` — React コンポーネントと状態管理の一般的なパターン
- `design-system` — デザイントークンとコンポーネントの一貫性
- `motion-foundations` と `motion-patterns`: アクセシビリティを考慮したアニメーションパターン
