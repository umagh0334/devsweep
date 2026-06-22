import Foundation
import SwiftUI

/// 앱 내 다국어. swiftc 단독 빌드(.lproj 번들 없이)라 Swift 번역 테이블 + environment 로 구현.
/// 언어 전환은 @AppStorage("language") → environment(\.appLanguage) → 뷰 재평가로 즉시 반영.

enum AppLanguage: String, CaseIterable, Identifiable {
    case en, ko, ja
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
    case th, vi, it, fr, es, pt, hr

    var id: String { rawValue }

    /// 각 언어를 그 언어로 표기 (picker용)
    var displayName: String {
        switch self {
        case .en: return "English"
        case .ko: return "한국어"
        case .ja: return "日本語"
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        case .th: return "ไทย"
        case .vi: return "Tiếng Việt"
        case .it: return "Italiano"
        case .fr: return "Français"
        case .es: return "Español"
        case .pt: return "Português"
        case .hr: return "Hrvatski"
        }
    }

    /// 시스템 선호 언어에서 추정 (최초 실행 기본값)
    static var systemDefault: AppLanguage {
        let p = Locale.preferredLanguages.first ?? "en"
        if p.hasPrefix("ko") { return .ko }
        if p.hasPrefix("ja") { return .ja }
        if p.hasPrefix("zh-Hant") || p.hasPrefix("zh-TW") || p.hasPrefix("zh-HK") || p.hasPrefix("zh-MO") { return .zhHant }
        if p.hasPrefix("zh") { return .zhHans }
        if p.hasPrefix("th") { return .th }
        if p.hasPrefix("vi") { return .vi }
        if p.hasPrefix("it") { return .it }
        if p.hasPrefix("fr") { return .fr }
        if p.hasPrefix("es") { return .es }
        if p.hasPrefix("pt") { return .pt }
        if p.hasPrefix("hr") { return .hr }
        return .en
    }
}

// ── environment 전파 ──
private struct AppLanguageKey: EnvironmentKey {
    static let defaultValue: AppLanguage = .en
}
extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }
}

// ── 조회 ──
func tr(_ key: String, _ lang: AppLanguage) -> String {
    L10n.table[key]?[lang] ?? L10n.table[key]?[.en] ?? key
}
func tr(_ key: String, _ lang: AppLanguage, _ args: CVarArg...) -> String {
    String(format: tr(key, lang), arguments: args)
}

/// CLI 가 내보내는 한국어 kind 값을 번역 키로 정규화 (행·디테일 헤더에서 사용)
func kindKey(_ kind: String) -> String {
    if kind.hasPrefix("재생성") { return "kind.regen" }
    if kind.contains("무거움") { return "kind.redownloadHeavy" }
    if kind.hasPrefix("재다운로드") { return "kind.redownload" }
    if kind.hasPrefix("prune") { return "kind.prune" }
    if kind.contains("시뮬레이터") { return "kind.sim" }
    if kind.contains("std") { return "kind.targets" }
    return kind
}

enum L10n {
    static let table: [String: [AppLanguage: String]] = [
        // ── 공통 ──
        "recoverable": [.en:"Recoverable", .ko:"회수 가능", .ja:"回収可能", .zhHans:"可回收", .zhHant:"可回收", .th:"กู้คืนได้", .vi:"Có thể thu hồi", .it:"Recuperabile", .fr:"Récupérable", .es:"Recuperable", .pt:"Recuperável", .hr:"Moguće vratiti"],
        "size": [.en:"Size", .ko:"용량", .ja:"容量", .zhHans:"大小", .zhHant:"大小", .th:"ขนาด", .vi:"Dung lượng", .it:"Dimensione", .fr:"Taille", .es:"Tamaño", .pt:"Tamanho", .hr:"Veličina"],

        // ── 헤더 ──
        "header.trackingFmt": [.en:"Tracking %d dev caches", .ko:"%d개 개발 캐시 추적 중", .ja:"%d個の開発キャッシュを追跡中", .zhHans:"正在追踪 %d 个开发缓存", .zhHant:"正在追蹤 %d 個開發快取", .th:"กำลังติดตามแคช %d รายการ", .vi:"Đang theo dõi %d bộ nhớ đệm", .it:"Monitoraggio di %d cache", .fr:"Suivi de %d caches", .es:"Rastreando %d cachés", .pt:"Rastreando %d caches", .hr:"Praćenje %d predmemorija"],
        "header.mostFmt": [.en:"%@ largest · %@", .ko:"%@ 최다 · %@", .ja:"%@ が最多 · %@", .zhHans:"%@ 最多 · %@", .zhHant:"%@ 最多 · %@", .th:"%@ มากที่สุด · %@", .vi:"%@ nhiều nhất · %@", .it:"%@ il maggiore · %@", .fr:"%@ le plus · %@", .es:"%@ el mayor · %@", .pt:"%@ o maior · %@", .hr:"%@ najveći · %@"],
        "header.othersFmt": [.en:"%d more", .ko:"외 %d종", .ja:"他 %d種", .zhHans:"另外 %d 项", .zhHant:"另外 %d 項", .th:"อีก %d รายการ", .vi:"%d mục khác", .it:"altri %d", .fr:"%d de plus", .es:"%d más", .pt:"mais %d", .hr:"još %d"],

        // ── 마스터 리스트 ──
        "master.empty": [.en:"No cache", .ko:"캐시 없음", .ja:"キャッシュなし", .zhHans:"无缓存", .zhHant:"無快取", .th:"ไม่มีแคช", .vi:"Không có bộ nhớ đệm", .it:"Nessuna cache", .fr:"Aucun cache", .es:"Sin caché", .pt:"Sem cache", .hr:"Bez predmemorije"],
        "master.tipSelect": [.en:"Select as cleanup target", .ko:"정리 대상으로 선택", .ja:"クリーンアップ対象に選択", .zhHans:"选为清理对象", .zhHant:"選為清理對象", .th:"เลือกเป็นรายการล้าง", .vi:"Chọn để dọn dẹp", .it:"Seleziona per la pulizia", .fr:"Sélectionner pour le nettoyage", .es:"Seleccionar para limpiar", .pt:"Selecionar para limpeza", .hr:"Odaberi za čišćenje"],
        "master.tipNoCache": [.en:"No cache to clean", .ko:"정리할 캐시가 없음", .ja:"クリーンアップするキャッシュがありません", .zhHans:"没有可清理的缓存", .zhHant:"沒有可清理的快取", .th:"ไม่มีแคชให้ล้าง", .vi:"Không có bộ nhớ đệm để dọn", .it:"Nessuna cache da pulire", .fr:"Aucun cache à nettoyer", .es:"No hay caché para limpiar", .pt:"Sem cache para limpar", .hr:"Nema predmemorije za čišćenje"],
        "master.tipProtected": [.en:"Protected — excluded from cleanup", .ko:"보호 목록에 있어 정리되지 않음", .ja:"保護リストにあり、クリーンアップされません", .zhHans:"在保护列表中，不会被清理", .zhHant:"在保護清單中，不會被清理", .th:"อยู่ในรายการป้องกัน จะไม่ถูกล้าง", .vi:"Được bảo vệ — không bị dọn", .it:"Protetto — escluso dalla pulizia", .fr:"Protégé — exclu du nettoyage", .es:"Protegido — excluido de la limpieza", .pt:"Protegido — excluído da limpeza", .hr:"Zaštićeno — isključeno iz čišćenja"],
        "badge.protect": [.en:"PROTECTED", .ko:"보호", .ja:"保護", .zhHans:"保护", .zhHant:"保護", .th:"ป้องกัน", .vi:"BẢO VỆ", .it:"PROTETTO", .fr:"PROTÉGÉ", .es:"PROTEGIDO", .pt:"PROTEGIDO", .hr:"ZAŠTIĆENO"],

        // ── 푸터 ──
        "footer.selectedFmt": [.en:"%d selected", .ko:"%d개 선택", .ja:"%d個選択", .zhHans:"已选 %d 项", .zhHant:"已選 %d 項", .th:"เลือก %d รายการ", .vi:"Đã chọn %d", .it:"%d selezionati", .fr:"%d sélectionnés", .es:"%d seleccionados", .pt:"%d selecionados", .hr:"%d odabrano"],
        "footer.willCleanFmt": [.en:"· %@ to be freed", .ko:"· %@ 정리 예정", .ja:"· %@ を整理予定", .zhHans:"· 将释放 %@", .zhHant:"· 將釋放 %@", .th:"· จะคืน %@", .vi:"· sẽ giải phóng %@", .it:"· %@ da liberare", .fr:"· %@ à libérer", .es:"· %@ a liberar", .pt:"· %@ a liberar", .hr:"· %@ za oslobađanje"],
        "footer.prompt": [.en:"Check items to clean up", .ko:"정리할 항목을 체크하세요", .ja:"整理する項目をチェックしてください", .zhHans:"勾选要清理的项目", .zhHant:"勾選要清理的項目", .th:"เลือกรายการที่จะล้าง", .vi:"Chọn mục cần dọn dẹp", .it:"Seleziona gli elementi da pulire", .fr:"Cochez les éléments à nettoyer", .es:"Marca los elementos a limpiar", .pt:"Marque os itens para limpar", .hr:"Označite stavke za čišćenje"],
        "footer.scanning": [.en:"Scanning…", .ko:"스캔 중…", .ja:"スキャン中…", .zhHans:"扫描中…", .zhHant:"掃描中…", .th:"กำลังสแกน…", .vi:"Đang quét…", .it:"Scansione…", .fr:"Analyse…", .es:"Escaneando…", .pt:"A analisar…", .hr:"Skeniranje…"],
        "footer.cleaning": [.en:"Cleaning…", .ko:"정리 중…", .ja:"整理中…", .zhHans:"清理中…", .zhHant:"清理中…", .th:"กำลังล้าง…", .vi:"Đang dọn…", .it:"Pulizia…", .fr:"Nettoyage…", .es:"Limpiando…", .pt:"A limpar…", .hr:"Čišćenje…"],
        "footer.rescan": [.en:"Rescan", .ko:"다시 스캔", .ja:"再スキャン", .zhHans:"重新扫描", .zhHant:"重新掃描", .th:"สแกนใหม่", .vi:"Quét lại", .it:"Riesegui scansione", .fr:"Réanalyser", .es:"Reescanear", .pt:"Reanalisar", .hr:"Ponovno skeniraj"],
        "footer.clean": [.en:"Clean selected", .ko:"선택 정리", .ja:"選択を整理", .zhHans:"清理所选", .zhHant:"清理所選", .th:"ล้างที่เลือก", .vi:"Dọn mục đã chọn", .it:"Pulisci selezionati", .fr:"Nettoyer la sélection", .es:"Limpiar selección", .pt:"Limpar selecionados", .hr:"Očisti odabrano"],
        "footer.settings": [.en:"Settings · Protect list", .ko:"환경설정 · 보호 목록", .ja:"設定 · 保護リスト", .zhHans:"设置 · 保护列表", .zhHant:"設定 · 保護清單", .th:"ตั้งค่า · รายการป้องกัน", .vi:"Cài đặt · Danh sách bảo vệ", .it:"Impostazioni · Lista protetti", .fr:"Réglages · Liste protégée", .es:"Ajustes · Lista protegida", .pt:"Definições · Lista protegida", .hr:"Postavke · Popis zaštite"],

        // ── 디테일 패널 ──
        "detail.empty": [.en:"Select an item to see\nits details here", .ko:"항목을 선택하면\n상세 정보가 여기 표시됩니다", .ja:"項目を選択すると\n詳細がここに表示されます", .zhHans:"选择项目后\n详情将显示在这里", .zhHant:"選擇項目後\n詳情將顯示在這裡", .th:"เลือกรายการเพื่อดู\nรายละเอียดที่นี่", .vi:"Chọn một mục để xem\nchi tiết tại đây", .it:"Seleziona un elemento per\nvederne i dettagli qui", .fr:"Sélectionnez un élément pour\nvoir ses détails ici", .es:"Selecciona un elemento para\nver sus detalles aquí", .pt:"Selecione um item para\nver os detalhes aqui", .hr:"Odaberite stavku za prikaz\npojedinosti ovdje"],
        "detail.analyzing": [.en:"Analyzing…", .ko:"상세 분석 중…", .ja:"詳細を分析中…", .zhHans:"正在分析…", .zhHant:"正在分析…", .th:"กำลังวิเคราะห์…", .vi:"Đang phân tích…", .it:"Analisi…", .fr:"Analyse…", .es:"Analizando…", .pt:"A analisar…", .hr:"Analiziranje…"],
        "detail.secPaths": [.en:"Size by path", .ko:"경로별 용량", .ja:"パス別の容量", .zhHans:"按路径大小", .zhHant:"依路徑大小", .th:"ขนาดตามพาธ", .vi:"Dung lượng theo đường dẫn", .it:"Dimensione per percorso", .fr:"Taille par chemin", .es:"Tamaño por ruta", .pt:"Tamanho por caminho", .hr:"Veličina po putanji"],
        "detail.secCommand": [.en:"Runs on cleanup", .ko:"정리 시 실행", .ja:"整理時に実行", .zhHans:"清理时执行", .zhHant:"清理時執行", .th:"คำสั่งเมื่อล้าง", .vi:"Lệnh khi dọn dẹp", .it:"Esegue alla pulizia", .fr:"Exécuté au nettoyage", .es:"Se ejecuta al limpiar", .pt:"Executa na limpeza", .hr:"Pokreće se pri čišćenju"],
        "detail.secAfter": [.en:"After cleanup", .ko:"정리 후", .ja:"整理後", .zhHans:"清理后", .zhHant:"清理後", .th:"หลังล้าง", .vi:"Sau khi dọn", .it:"Dopo la pulizia", .fr:"Après le nettoyage", .es:"Después de limpiar", .pt:"Após a limpeza", .hr:"Nakon čišćenja"],
        "detail.methodNative": [.en:"Native tool", .ko:"네이티브 도구", .ja:"ネイティブツール", .zhHans:"原生工具", .zhHant:"原生工具", .th:"เครื่องมือเนทีฟ", .vi:"Công cụ gốc", .it:"Strumento nativo", .fr:"Outil natif", .es:"Herramienta nativa", .pt:"Ferramenta nativa", .hr:"Izvorni alat"],
        "detail.methodRm": [.en:"Direct rm", .ko:"rm 직접", .ja:"rm を直接", .zhHans:"直接 rm", .zhHant:"直接 rm", .th:"rm โดยตรง", .vi:"rm trực tiếp", .it:"rm diretto", .fr:"rm direct", .es:"rm directo", .pt:"rm direto", .hr:"izravni rm"],
        "detail.failPrefix": [.en:"On failure", .ko:"실패 시", .ja:"失敗時", .zhHans:"失败时", .zhHant:"失敗時", .th:"เมื่อล้มเหลว", .vi:"Khi thất bại", .it:"In caso di errore", .fr:"En cas d'échec", .es:"Si falla", .pt:"Em caso de falha", .hr:"U slučaju greške"],
        "detail.cleanThis": [.en:"Clean this", .ko:"이 항목 정리", .ja:"この項目を整理", .zhHans:"清理此项", .zhHant:"清理此項", .th:"ล้างรายการนี้", .vi:"Dọn mục này", .it:"Pulisci questo", .fr:"Nettoyer ceci", .es:"Limpiar esto", .pt:"Limpar isto", .hr:"Očisti ovo"],
        "detail.cleanThisInfoFmt": [.en:"Cleaning this frees %@", .ko:"이 항목만 정리하면 %@ 확보", .ja:"この項目だけで %@ を確保", .zhHans:"仅清理此项可释放 %@", .zhHant:"僅清理此項可釋放 %@", .th:"ล้างเฉพาะนี้ได้คืน %@", .vi:"Dọn mục này giải phóng %@", .it:"Pulendo questo liberi %@", .fr:"Nettoyer ceci libère %@", .es:"Limpiar esto libera %@", .pt:"Limpar isto liberta %@", .hr:"Čišćenje ovoga oslobađa %@"],
        "detail.copyHelp": [.en:"Copy command", .ko:"명령 복사", .ja:"コマンドをコピー", .zhHans:"复制命令", .zhHant:"複製指令", .th:"คัดลอกคำสั่ง", .vi:"Sao chép lệnh", .it:"Copia comando", .fr:"Copier la commande", .es:"Copiar comando", .pt:"Copiar comando", .hr:"Kopiraj naredbu"],

        // ── 배지 ──
        "badge.safe": [.en:"Safe", .ko:"안전", .ja:"安全", .zhHans:"安全", .zhHant:"安全", .th:"ปลอดภัย", .vi:"An toàn", .it:"Sicuro", .fr:"Sûr", .es:"Seguro", .pt:"Seguro", .hr:"Sigurno"],
        "badge.caution": [.en:"Caution", .ko:"주의", .ja:"注意", .zhHans:"注意", .zhHant:"注意", .th:"ระวัง", .vi:"Thận trọng", .it:"Attenzione", .fr:"Attention", .es:"Precaución", .pt:"Cuidado", .hr:"Oprez"],
        "cost.low": [.en:"Low cost", .ko:"저비용", .ja:"低コスト", .zhHans:"低成本", .zhHant:"低成本", .th:"ต้นทุนต่ำ", .vi:"Chi phí thấp", .it:"Basso costo", .fr:"Faible coût", .es:"Bajo costo", .pt:"Baixo custo", .hr:"Niski trošak"],
        "cost.med": [.en:"Medium cost", .ko:"중비용", .ja:"中コスト", .zhHans:"中等成本", .zhHant:"中等成本", .th:"ต้นทุนปานกลาง", .vi:"Chi phí trung bình", .it:"Costo medio", .fr:"Coût moyen", .es:"Costo medio", .pt:"Custo médio", .hr:"Srednji trošak"],
        "cost.high": [.en:"High cost", .ko:"고비용", .ja:"高コスト", .zhHans:"高成本", .zhHant:"高成本", .th:"ต้นทุนสูง", .vi:"Chi phí cao", .it:"Costo elevato", .fr:"Coût élevé", .es:"Costo alto", .pt:"Custo alto", .hr:"Visoki trošak"],
        "badge.protected": [.en:"Protected", .ko:"보호됨", .ja:"保護中", .zhHans:"已保护", .zhHant:"已保護", .th:"ได้รับการป้องกัน", .vi:"Được bảo vệ", .it:"Protetto", .fr:"Protégé", .es:"Protegido", .pt:"Protegido", .hr:"Zaštićeno"],
        "badge.tcc": [.en:"Full Disk Access", .ko:"전체 디스크 접근", .ja:"フルディスクアクセス", .zhHans:"完全磁盘访问", .zhHant:"完全磁碟存取", .th:"การเข้าถึงดิสก์เต็มรูปแบบ", .vi:"Toàn quyền truy cập đĩa", .it:"Accesso completo al disco", .fr:"Accès complet au disque", .es:"Acceso total al disco", .pt:"Acesso total ao disco", .hr:"Potpuni pristup disku"],
        "badge.noTool": [.en:"No tool → rm", .ko:"도구 없음→rm", .ja:"ツールなし→rm", .zhHans:"无工具→rm", .zhHant:"無工具→rm", .th:"ไม่มีเครื่องมือ→rm", .vi:"Không có công cụ→rm", .it:"Nessuno strumento→rm", .fr:"Pas d'outil→rm", .es:"Sin herramienta→rm", .pt:"Sem ferramenta→rm", .hr:"Nema alata→rm"],

        // ── 경로 행 ──
        "path.none": [.en:"None", .ko:"없음", .ja:"なし", .zhHans:"无", .zhHant:"無", .th:"ไม่มี", .vi:"Không có", .it:"Nessuno", .fr:"Aucun", .es:"Ninguno", .pt:"Nenhum", .hr:"Ništa"],
        "path.perm": [.en:"Permission needed", .ko:"권한 필요", .ja:"権限が必要", .zhHans:"需要权限", .zhHant:"需要權限", .th:"ต้องการสิทธิ์", .vi:"Cần quyền", .it:"Permesso richiesto", .fr:"Autorisation requise", .es:"Permiso necesario", .pt:"Permissão necessária", .hr:"Potrebno dopuštenje"],

        // ── kind (CLI → 정규화) ──
        "kind.regen": [.en:"Regenerated", .ko:"재생성", .ja:"再生成", .zhHans:"重新生成", .zhHant:"重新產生", .th:"สร้างใหม่", .vi:"Tạo lại", .it:"Rigenerato", .fr:"Régénéré", .es:"Regenerado", .pt:"Regenerado", .hr:"Ponovno stvoreno"],
        "kind.redownload": [.en:"Re-downloaded", .ko:"재다운로드", .ja:"再ダウンロード", .zhHans:"重新下载", .zhHant:"重新下載", .th:"ดาวน์โหลดใหม่", .vi:"Tải lại", .it:"Riscaricato", .fr:"Retéléchargé", .es:"Redescargado", .pt:"Rebaixado", .hr:"Ponovno preuzeto"],
        "kind.redownloadHeavy": [.en:"Re-downloaded (heavy)", .ko:"재다운로드(무거움)", .ja:"再ダウンロード(重い)", .zhHans:"重新下载(较大)", .zhHant:"重新下載(較大)", .th:"ดาวน์โหลดใหม่(หนัก)", .vi:"Tải lại (nặng)", .it:"Riscaricato (pesante)", .fr:"Retéléchargé (lourd)", .es:"Redescargado (pesado)", .pt:"Rebaixado (pesado)", .hr:"Ponovno preuzeto (veliko)"],
        "kind.prune": [.en:"Prune", .ko:"prune", .ja:"prune", .zhHans:"清除(prune)", .zhHant:"清除(prune)", .th:"prune", .vi:"Prune", .it:"Prune", .fr:"Prune", .es:"Prune", .pt:"Prune", .hr:"Prune"],
        "kind.sim": [.en:"Unavailable simulators", .ko:"사용불가 시뮬레이터", .ja:"使用不可シミュレータ", .zhHans:"不可用的模拟器", .zhHant:"無法使用的模擬器", .th:"ซิมูเลเตอร์ที่ใช้ไม่ได้", .vi:"Trình mô phỏng không khả dụng", .it:"Simulatori non disponibili", .fr:"Simulateurs indisponibles", .es:"Simuladores no disponibles", .pt:"Simuladores indisponíveis", .hr:"Nedostupni simulatori"],
        "kind.targets": [.en:"Unused std components", .ko:"안 쓰는 std 컴포넌트", .ja:"未使用の std コンポーネント", .zhHans:"未使用的 std 组件", .zhHant:"未使用的 std 元件", .th:"คอมโพเนนต์ std ที่ไม่ใช้", .vi:"Thành phần std không dùng", .it:"Componenti std inutilizzati", .fr:"Composants std inutilisés", .es:"Componentes std sin usar", .pt:"Componentes std não usados", .hr:"Nekorištene std komponente"],

        // ── 재생성 노트 (regen_cost 기반) ──
        "regen.low": [.en:"Automatically regenerated locally on next use (no download).", .ko:"다음 사용 시 로컬에서 자동 재생성됩니다 (다운로드 없음).", .ja:"次回使用時にローカルで自動的に再生成されます(ダウンロード不要)。", .zhHans:"下次使用时在本地自动重新生成(无需下载)。", .zhHant:"下次使用時在本機自動重新產生(無需下載)。", .th:"จะถูกสร้างใหม่อัตโนมัติในเครื่องเมื่อใช้ครั้งถัดไป (ไม่ต้องดาวน์โหลด)", .vi:"Tự động tạo lại cục bộ ở lần dùng tới (không tải về).", .it:"Rigenerato automaticamente in locale al prossimo utilizzo (nessun download).", .fr:"Régénéré automatiquement en local à la prochaine utilisation (sans téléchargement).", .es:"Se regenera automáticamente en local en el próximo uso (sin descarga).", .pt:"Regenerado automaticamente localmente no próximo uso (sem download).", .hr:"Automatski se ponovno stvara lokalno pri sljedećoj upotrebi (bez preuzimanja)."],
        "regen.med": [.en:"Re-downloaded from the registry on next use.", .ko:"다음 사용 시 레지스트리에서 다시 받습니다.", .ja:"次回使用時にレジストリから再ダウンロードされます。", .zhHans:"下次使用时会从仓库重新下载。", .zhHant:"下次使用時會從套件庫重新下載。", .th:"จะดาวน์โหลดใหม่จากรีจิสทรีเมื่อใช้ครั้งถัดไป", .vi:"Được tải lại từ registry ở lần dùng tới.", .it:"Riscaricato dal registro al prossimo utilizzo.", .fr:"Retéléchargé depuis le registre à la prochaine utilisation.", .es:"Se vuelve a descargar del registro en el próximo uso.", .pt:"Rebaixado do registo no próximo uso.", .hr:"Ponovno se preuzima iz registra pri sljedećoj upotrebi."],
        "regen.high": [.en:"A large amount must be re-downloaded (takes time).", .ko:"큰 용량을 다시 받아야 합니다 (시간 소요).", .ja:"大きな容量を再ダウンロードする必要があります(時間がかかります)。", .zhHans:"需要重新下载大量数据(较耗时)。", .zhHant:"需要重新下載大量資料(較耗時)。", .th:"ต้องดาวน์โหลดข้อมูลจำนวนมากใหม่ (ใช้เวลานาน)", .vi:"Phải tải lại dung lượng lớn (mất thời gian).", .it:"Va riscaricata una grande quantità (richiede tempo).", .fr:"Une grande quantité doit être retéléchargée (cela prend du temps).", .es:"Hay que volver a descargar una gran cantidad (lleva tiempo).", .pt:"É preciso rebaixar uma grande quantidade (demora).", .hr:"Treba ponovno preuzeti veliku količinu (oduzima vrijeme)."],

        // ── 안전성 노트 (safety 코드 기반) ──
        "safety.safe": [.en:"Pure cache — no effect on source or projects.", .ko:"순수 캐시라 소스·프로젝트엔 영향 없음.", .ja:"純粋なキャッシュなので、ソースやプロジェクトに影響しません。", .zhHans:"纯缓存,不影响源码或项目。", .zhHant:"純快取,不影響原始碼或專案。", .th:"เป็นแคชล้วน ไม่กระทบซอร์สหรือโปรเจกต์", .vi:"Chỉ là bộ nhớ đệm — không ảnh hưởng mã nguồn hay dự án.", .it:"Cache pura — nessun effetto su sorgenti o progetti.", .fr:"Cache pur — aucun effet sur le code ou les projets.", .es:"Caché puro — sin efecto en el código ni los proyectos.", .pt:"Cache puro — sem efeito no código ou projetos.", .hr:"Čista predmemorija — bez utjecaja na izvor ili projekte."],
        "safety.caution": [.en:"Reinstall/redownload is costly. Fine to clean if rarely used.", .ko:"재설치/재다운로드 비용이 큼. 자주 안 쓰면 정리해도 됨.", .ja:"再インストール/再ダウンロードのコストが大きい。あまり使わないなら整理可。", .zhHans:"重装/重新下载成本高。不常用可以清理。", .zhHant:"重裝/重新下載成本高。不常用可以清理。", .th:"การติดตั้ง/ดาวน์โหลดใหม่มีต้นทุนสูง หากไม่ค่อยใช้ก็ล้างได้", .vi:"Cài/tải lại tốn kém. Có thể dọn nếu ít dùng.", .it:"Reinstallare/riscaricare è costoso. Si può pulire se usato di rado.", .fr:"Réinstaller/retélécharger coûte cher. Nettoyez si rarement utilisé.", .es:"Reinstalar/redescargar es costoso. Puedes limpiar si lo usas poco.", .pt:"Reinstalar/rebaixar é caro. Pode limpar se usar pouco.", .hr:"Ponovna instalacija/preuzimanje je skupo. Slobodno očistite ako rijetko koristite."],

        // ── 설정: 섹션 ──
        "set.general": [.en:"General", .ko:"일반", .ja:"一般", .zhHans:"通用", .zhHant:"一般", .th:"ทั่วไป", .vi:"Chung", .it:"Generale", .fr:"Général", .es:"General", .pt:"Geral", .hr:"Općenito"],
        "set.protect": [.en:"Protect list", .ko:"보호 목록", .ja:"保護リスト", .zhHans:"保护列表", .zhHant:"保護清單", .th:"รายการป้องกัน", .vi:"Danh sách bảo vệ", .it:"Lista protetti", .fr:"Liste protégée", .es:"Lista protegida", .pt:"Lista protegida", .hr:"Popis zaštite"],
        "set.age": [.en:"Age filter", .ko:"나이 필터", .ja:"経過日数フィルタ", .zhHans:"按时间筛选", .zhHant:"依時間篩選", .th:"ตัวกรองอายุ", .vi:"Lọc theo tuổi", .it:"Filtro età", .fr:"Filtre d'âge", .es:"Filtro por antigüedad", .pt:"Filtro por idade", .hr:"Filtar po starosti"],
        "set.schedule": [.en:"Auto cleanup", .ko:"자동 정리", .ja:"自動整理", .zhHans:"自动清理", .zhHant:"自動清理", .th:"ล้างอัตโนมัติ", .vi:"Dọn tự động", .it:"Pulizia automatica", .fr:"Nettoyage auto", .es:"Limpieza automática", .pt:"Limpeza automática", .hr:"Automatsko čišćenje"],
        "set.about": [.en:"About", .ko:"정보", .ja:"情報", .zhHans:"关于", .zhHant:"關於", .th:"เกี่ยวกับ", .vi:"Giới thiệu", .it:"Informazioni", .fr:"À propos", .es:"Acerca de", .pt:"Acerca de", .hr:"O aplikaciji"],

        // ── 설정: 일반 ──
        "general.sub": [.en:"Configure appearance and scan behavior.", .ko:"앱 외관과 스캔 동작을 설정합니다.", .ja:"アプリの外観とスキャン動作を設定します。", .zhHans:"设置应用外观和扫描行为。", .zhHant:"設定應用程式外觀與掃描行為。", .th:"ตั้งค่ารูปลักษณ์และพฤติกรรมการสแกน", .vi:"Cấu hình giao diện và hành vi quét.", .it:"Configura aspetto e comportamento della scansione.", .fr:"Configurez l'apparence et le comportement d'analyse.", .es:"Configura la apariencia y el escaneo.", .pt:"Configure a aparência e o comportamento de análise.", .hr:"Postavite izgled i ponašanje skeniranja."],
        "general.language": [.en:"Language", .ko:"언어", .ja:"言語", .zhHans:"语言", .zhHant:"語言", .th:"ภาษา", .vi:"Ngôn ngữ", .it:"Lingua", .fr:"Langue", .es:"Idioma", .pt:"Idioma", .hr:"Jezik"],
        "general.appearance": [.en:"Appearance", .ko:"외관", .ja:"外観", .zhHans:"外观", .zhHant:"外觀", .th:"รูปลักษณ์", .vi:"Giao diện", .it:"Aspetto", .fr:"Apparence", .es:"Apariencia", .pt:"Aparência", .hr:"Izgled"],
        "general.system": [.en:"System", .ko:"시스템", .ja:"システム", .zhHans:"系统", .zhHant:"系統", .th:"ระบบ", .vi:"Hệ thống", .it:"Sistema", .fr:"Système", .es:"Sistema", .pt:"Sistema", .hr:"Sustav"],
        "general.light": [.en:"Light", .ko:"라이트", .ja:"ライト", .zhHans:"浅色", .zhHant:"淺色", .th:"สว่าง", .vi:"Sáng", .it:"Chiaro", .fr:"Clair", .es:"Claro", .pt:"Claro", .hr:"Svijetlo"],
        "general.dark": [.en:"Dark", .ko:"다크", .ja:"ダーク", .zhHans:"深色", .zhHant:"深色", .th:"มืด", .vi:"Tối", .it:"Scuro", .fr:"Sombre", .es:"Oscuro", .pt:"Escuro", .hr:"Tamno"],
        "general.autoScan": [.en:"Auto-scan on launch", .ko:"앱 시작 시 자동 스캔", .ja:"起動時に自動スキャン", .zhHans:"启动时自动扫描", .zhHant:"啟動時自動掃描", .th:"สแกนอัตโนมัติเมื่อเปิด", .vi:"Tự quét khi mở", .it:"Scansione automatica all'avvio", .fr:"Analyse auto au lancement", .es:"Escaneo automático al abrir", .pt:"Análise automática ao abrir", .hr:"Automatsko skeniranje pri pokretanju"],
        "general.autoScanDesc": [.en:"If off, press ‘Rescan’ manually.", .ko:"끄면 직접 ‘다시 스캔’을 눌러야 합니다.", .ja:"オフの場合は手動で「再スキャン」を押してください。", .zhHans:"关闭后需手动点击“重新扫描”。", .zhHant:"關閉後需手動點選「重新掃描」。", .th:"หากปิด ต้องกด ‘สแกนใหม่’ เอง", .vi:"Nếu tắt, hãy nhấn ‘Quét lại’ thủ công.", .it:"Se disattivato, premi ‘Riesegui scansione’.", .fr:"Si désactivé, appuyez sur ‘Réanalyser’.", .es:"Si está apagado, pulsa ‘Reescanear’.", .pt:"Se desligado, prima ‘Reanalisar’.", .hr:"Ako je isključeno, ručno pritisnite ‘Ponovno skeniraj’."],
        "general.selectHeavy": [.en:"Also select HEAVY categories", .ko:"HEAVY 카테고리도 기본 선택", .ja:"HEAVY カテゴリも既定で選択", .zhHans:"默认也选中 HEAVY 类别", .zhHant:"預設也選取 HEAVY 類別", .th:"เลือกหมวด HEAVY ด้วย", .vi:"Cũng chọn các mục HEAVY", .it:"Seleziona anche le categorie HEAVY", .fr:"Sélectionner aussi les catégories HEAVY", .es:"Seleccionar también categorías HEAVY", .pt:"Selecionar também categorias HEAVY", .hr:"Također odaberi HEAVY kategorije"],
        "general.selectHeavyDesc": [.en:"Auto-checks costly-to-redownload items (e.g. playwright) after scan.", .ko:"재다운로드 비용이 큰 항목(playwright 등)을 스캔 후 자동 체크합니다.", .ja:"再ダウンロードコストの大きい項目(playwright など)をスキャン後に自動チェックします。", .zhHans:"扫描后自动勾选重新下载成本高的项目(如 playwright)。", .zhHant:"掃描後自動勾選重新下載成本高的項目(如 playwright)。", .th:"เลือกอัตโนมัติสำหรับรายการที่ดาวน์โหลดใหม่แพง (เช่น playwright) หลังสแกน", .vi:"Tự chọn các mục tốn kém khi tải lại (vd: playwright) sau khi quét.", .it:"Seleziona automaticamente gli elementi costosi da riscaricare (es. playwright) dopo la scansione.", .fr:"Coche automatiquement les éléments coûteux à retélécharger (ex. playwright) après l'analyse.", .es:"Marca automáticamente los elementos costosos de redescargar (p. ej. playwright) tras escanear.", .pt:"Marca automaticamente itens caros de rebaixar (ex. playwright) após a análise.", .hr:"Nakon skeniranja automatski označi stavke skupe za ponovno preuzimanje (npr. playwright)."],

        // ── 설정: 보호 목록 ──
        "protect.sub": [.en:"Categories turned on here are permanently excluded from cleanup — their cache is kept and devsweep won't touch it.", .ko:"켜둔 카테고리는 정리에서 영구 제외됩니다 — 캐시가 보존되고 devsweep이 건드리지 않습니다.", .ja:"オンにしたカテゴリは整理から永久に除外されます — キャッシュは保持され、devsweep は触れません。", .zhHans:"开启的类别将永久排除在清理之外——缓存会保留,devsweep 不会触碰。", .zhHant:"開啟的類別將永久排除在清理之外——快取會保留,devsweep 不會觸碰。", .th:"หมวดที่เปิดไว้จะถูกยกเว้นจากการล้างถาวร — แคชจะถูกเก็บไว้และ devsweep จะไม่แตะต้อง", .vi:"Các mục bật ở đây sẽ bị loại trừ vĩnh viễn khỏi việc dọn — bộ nhớ đệm được giữ và devsweep không động tới.", .it:"Le categorie attivate qui sono escluse in modo permanente dalla pulizia — la cache viene mantenuta e devsweep non la tocca.", .fr:"Les catégories activées ici sont définitivement exclues du nettoyage — leur cache est conservé et devsweep n'y touche pas.", .es:"Las categorías activadas aquí se excluyen permanentemente de la limpieza — su caché se conserva y devsweep no la toca.", .pt:"As categorias ativadas aqui ficam permanentemente excluídas da limpeza — a cache é mantida e o devsweep não lhe toca.", .hr:"Ovdje uključene kategorije trajno su isključene iz čišćenja — predmemorija se zadržava i devsweep je ne dira."],
        "protect.countFmt": [.en:"%d protected", .ko:"보호됨 %d개", .ja:"保護中 %d個", .zhHans:"已保护 %d 项", .zhHant:"已保護 %d 項", .th:"ป้องกัน %d รายการ", .vi:"%d được bảo vệ", .it:"%d protetti", .fr:"%d protégés", .es:"%d protegidos", .pt:"%d protegidos", .hr:"%d zaštićeno"],
        "protect.on": [.en:"Protect (exclude from cleanup)", .ko:"보호 (정리에서 제외)", .ja:"保護(整理から除外)", .zhHans:"保护(排除清理)", .zhHant:"保護(排除清理)", .th:"ป้องกัน (ยกเว้นการล้าง)", .vi:"Bảo vệ (loại khỏi dọn)", .it:"Proteggi (escludi dalla pulizia)", .fr:"Protéger (exclure du nettoyage)", .es:"Proteger (excluir de limpieza)", .pt:"Proteger (excluir da limpeza)", .hr:"Zaštiti (isključi iz čišćenja)"],
        "protect.off": [.en:"Unprotect", .ko:"보호 해제", .ja:"保護を解除", .zhHans:"取消保护", .zhHant:"取消保護", .th:"ยกเลิกการป้องกัน", .vi:"Bỏ bảo vệ", .it:"Rimuovi protezione", .fr:"Retirer la protection", .es:"Quitar protección", .pt:"Remover proteção", .hr:"Ukloni zaštitu"],

        // ── 설정: 정보 ──
        "about.tagline": [.en:"Developer cache cleaner", .ko:"개발 캐시 정리 도구", .ja:"開発キャッシュ整理ツール", .zhHans:"开发缓存清理工具", .zhHant:"開發快取清理工具", .th:"เครื่องมือล้างแคชสำหรับนักพัฒนา", .vi:"Công cụ dọn bộ nhớ đệm cho lập trình viên", .it:"Pulitore di cache per sviluppatori", .fr:"Nettoyeur de cache de développement", .es:"Limpiador de caché para desarrolladores", .pt:"Limpador de cache de desenvolvimento", .hr:"Čistač razvojne predmemorije"],
        "about.config": [.en:"Config file", .ko:"설정 파일", .ja:"設定ファイル", .zhHans:"配置文件", .zhHant:"設定檔", .th:"ไฟล์ตั้งค่า", .vi:"Tệp cấu hình", .it:"File di configurazione", .fr:"Fichier de config", .es:"Archivo de configuración", .pt:"Ficheiro de configuração", .hr:"Konfiguracijska datoteka"],
        "about.total": [.en:"Total recoverable", .ko:"총 회수 가능", .ja:"回収可能合計", .zhHans:"可回收总量", .zhHant:"可回收總量", .th:"กู้คืนได้ทั้งหมด", .vi:"Tổng có thể thu hồi", .it:"Totale recuperabile", .fr:"Total récupérable", .es:"Total recuperable", .pt:"Total recuperável", .hr:"Ukupno povrativo"],
        "about.cats": [.en:"Categories", .ko:"카테고리", .ja:"カテゴリ", .zhHans:"类别", .zhHant:"類別", .th:"หมวดหมู่", .vi:"Danh mục", .it:"Categorie", .fr:"Catégories", .es:"Categorías", .pt:"Categorias", .hr:"Kategorije"],
        "about.catsFmt": [.en:"%d types", .ko:"%d종", .ja:"%d種", .zhHans:"%d 种", .zhHant:"%d 種", .th:"%d ชนิด", .vi:"%d loại", .it:"%d tipi", .fr:"%d types", .es:"%d tipos", .pt:"%d tipos", .hr:"%d vrsta"],
        "about.icons": [.en:"Icons", .ko:"아이콘", .ja:"アイコン", .zhHans:"图标", .zhHant:"圖示", .th:"ไอคอน", .vi:"Biểu tượng", .it:"Icone", .fr:"Icônes", .es:"Iconos", .pt:"Ícones", .hr:"Ikone"],

        // ── 준비 중 섹션 ──
        "coming.ageDesc": [.en:"Set a default age threshold to clean only old caches — coming soon.\nFor now use the CLI:  devsweep clean --older-than 30d", .ko:"오래된 캐시만 정리하는 기본 기간을 설정합니다 — 준비 중.\n지금은 CLI에서  devsweep clean --older-than 30d  로 사용하세요.", .ja:"古いキャッシュだけを整理する既定の期間を設定します — 準備中。\n今は CLI で  devsweep clean --older-than 30d  をご利用ください。", .zhHans:"设置默认时间阈值,仅清理旧缓存——即将推出。\n目前请用 CLI:  devsweep clean --older-than 30d", .zhHant:"設定預設時間門檻,僅清理舊快取——即將推出。\n目前請用 CLI:  devsweep clean --older-than 30d", .th:"ตั้งเกณฑ์อายุเริ่มต้นเพื่อล้างเฉพาะแคชเก่า — เร็วๆ นี้\nตอนนี้ใช้ CLI:  devsweep clean --older-than 30d", .vi:"Đặt ngưỡng tuổi mặc định để chỉ dọn bộ nhớ đệm cũ — sắp ra mắt.\nHiện dùng CLI:  devsweep clean --older-than 30d", .it:"Imposta una soglia di età predefinita per pulire solo le cache vecchie — in arrivo.\nPer ora usa la CLI:  devsweep clean --older-than 30d", .fr:"Définir un seuil d'âge par défaut pour ne nettoyer que les vieux caches — bientôt.\nPour l'instant, utilisez la CLI :  devsweep clean --older-than 30d", .es:"Define un umbral de antigüedad para limpiar solo cachés viejas — próximamente.\nPor ahora usa la CLI:  devsweep clean --older-than 30d", .pt:"Defina um limite de idade para limpar apenas caches antigas — em breve.\nPor agora use a CLI:  devsweep clean --older-than 30d", .hr:"Postavi zadani prag starosti za čišćenje samo starih predmemorija — uskoro.\nZasad koristite CLI:  devsweep clean --older-than 30d"],
        "coming.scheduleDesc": [.en:"Automatically clean caches on a schedule (launchd) — coming soon.", .ko:"주기적으로 캐시를 자동 정리합니다 (launchd) — 준비 중.", .ja:"定期的にキャッシュを自動整理します(launchd) — 準備中。", .zhHans:"按计划自动清理缓存(launchd)——即将推出。", .zhHant:"依排程自動清理快取(launchd)——即將推出。", .th:"ล้างแคชอัตโนมัติตามกำหนดเวลา (launchd) — เร็วๆ นี้", .vi:"Tự động dọn bộ nhớ đệm theo lịch (launchd) — sắp ra mắt.", .it:"Pulisce automaticamente le cache su pianificazione (launchd) — in arrivo.", .fr:"Nettoie automatiquement les caches selon un planning (launchd) — bientôt.", .es:"Limpia cachés automáticamente según un horario (launchd) — próximamente.", .pt:"Limpa caches automaticamente por agendamento (launchd) — em breve.", .hr:"Automatski čisti predmemorije po rasporedu (launchd) — uskoro."],

        // ── 앱 메뉴 (커스텀 항목) ──
        "menu.settings": [.en:"Settings…", .ko:"설정…", .ja:"設定…", .zhHans:"设置…", .zhHant:"設定…", .th:"การตั้งค่า…", .vi:"Cài đặt…", .it:"Impostazioni…", .fr:"Réglages…", .es:"Ajustes…", .pt:"Definições…", .hr:"Postavke…"],

        // ── 나이 필터 ──
        "age.label": [.en:"Age threshold", .ko:"기간 기준", .ja:"期間のしきい値", .zhHans:"时间阈值", .zhHant:"時間門檻", .th:"เกณฑ์อายุ", .vi:"Ngưỡng tuổi", .it:"Soglia di età", .fr:"Seuil d'âge", .es:"Umbral de antigüedad", .pt:"Limite de idade", .hr:"Prag starosti"],
        "age.off": [.en:"Off", .ko:"끄기", .ja:"オフ", .zhHans:"关闭", .zhHant:"關閉", .th:"ปิด", .vi:"Tắt", .it:"Off", .fr:"Désactivé", .es:"Desactivado", .pt:"Desligado", .hr:"Isključeno"],
        "age.daysFmt": [.en:"%d days or older", .ko:"%d일 이상", .ja:"%d日以上", .zhHans:"%d 天以上", .zhHant:"%d 天以上", .th:"%d วันขึ้นไป", .vi:"Từ %d ngày", .it:"%d giorni o più", .fr:"%d jours ou plus", .es:"%d días o más", .pt:"%d dias ou mais", .hr:"%d dana ili više"],
        "age.note": [.en:"Only files older than the selected period are cleaned. Categories without a path (docker, simulators, rustup) are excluded.", .ko:"선택한 기간보다 오래된 파일만 정리됩니다. 경로가 없는 항목(docker·시뮬레이터·rustup)은 제외됩니다.", .ja:"選択した期間より古いファイルのみ整理されます。パスのない項目(docker・シミュレータ・rustup)は除外されます。", .zhHans:"仅清理早于所选时间的文件。无路径的项目(docker、模拟器、rustup)将被排除。", .zhHant:"僅清理早於所選時間的檔案。無路徑的項目(docker、模擬器、rustup)將被排除。", .th:"ล้างเฉพาะไฟล์ที่เก่ากว่าช่วงที่เลือก รายการที่ไม่มีพาธ (docker, ซิมูเลเตอร์, rustup) จะถูกยกเว้น", .vi:"Chỉ dọn các tệp cũ hơn khoảng thời gian đã chọn. Các mục không có đường dẫn (docker, trình mô phỏng, rustup) bị loại trừ.", .it:"Vengono puliti solo i file più vecchi del periodo selezionato. Le categorie senza percorso (docker, simulatori, rustup) sono escluse.", .fr:"Seuls les fichiers plus anciens que la période choisie sont nettoyés. Les catégories sans chemin (docker, simulateurs, rustup) sont exclues.", .es:"Solo se limpian los archivos más antiguos que el período seleccionado. Se excluyen las categorías sin ruta (docker, simuladores, rustup).", .pt:"Apenas os ficheiros mais antigos que o período selecionado são limpos. Categorias sem caminho (docker, simuladores, rustup) são excluídas.", .hr:"Čiste se samo datoteke starije od odabranog razdoblja. Kategorije bez putanje (docker, simulatori, rustup) su isključene."],
        "age.badgeFmt": [.en:"%d days+ only", .ko:"%d일+ 만", .ja:"%d日+ のみ", .zhHans:"仅 %d 天+", .zhHant:"僅 %d 天+", .th:"เฉพาะ %d วัน+", .vi:"Chỉ %d ngày+", .it:"Solo %d giorni+", .fr:"%d jours+ uniq.", .es:"Solo %d días+", .pt:"Só %d dias+", .hr:"Samo %d dana+"],

        // ── 정보 (버전·업데이트·통계·저작권·제작자) ──
        "about.version": [.en:"Version", .ko:"버전", .ja:"バージョン", .zhHans:"版本", .zhHant:"版本", .th:"เวอร์ชัน", .vi:"Phiên bản", .it:"Versione", .fr:"Version", .es:"Versión", .pt:"Versão", .hr:"Verzija"],
        "about.checkUpdate": [.en:"Check for updates", .ko:"업데이트 확인", .ja:"アップデートを確認", .zhHans:"检查更新", .zhHant:"檢查更新", .th:"ตรวจหาอัปเดต", .vi:"Kiểm tra cập nhật", .it:"Cerca aggiornamenti", .fr:"Rechercher des mises à jour", .es:"Buscar actualizaciones", .pt:"Procurar atualizações", .hr:"Provjeri ažuriranja"],
        "about.checking": [.en:"Checking…", .ko:"확인 중…", .ja:"確認中…", .zhHans:"检查中…", .zhHant:"檢查中…", .th:"กำลังตรวจสอบ…", .vi:"Đang kiểm tra…", .it:"Controllo…", .fr:"Vérification…", .es:"Comprobando…", .pt:"A verificar…", .hr:"Provjera…"],
        "about.upToDate": [.en:"Up to date", .ko:"최신 버전입니다", .ja:"最新です", .zhHans:"已是最新", .zhHant:"已是最新", .th:"เป็นเวอร์ชันล่าสุด", .vi:"Đã là mới nhất", .it:"Aggiornato", .fr:"À jour", .es:"Actualizado", .pt:"Atualizado", .hr:"Ažurno"],
        "about.updateAvailFmt": [.en:"%@ available", .ko:"%@ 사용 가능", .ja:"%@ が利用可能", .zhHans:"%@ 可用", .zhHant:"%@ 可用", .th:"มี %@", .vi:"Có %@", .it:"%@ disponibile", .fr:"%@ disponible", .es:"%@ disponible", .pt:"%@ disponível", .hr:"%@ dostupno"],
        "about.updateFailed": [.en:"Check failed", .ko:"확인 실패", .ja:"確認に失敗", .zhHans:"检查失败", .zhHant:"檢查失敗", .th:"ตรวจสอบไม่สำเร็จ", .vi:"Kiểm tra thất bại", .it:"Controllo fallito", .fr:"Échec de la vérification", .es:"Error al comprobar", .pt:"Falha na verificação", .hr:"Provjera neuspjela"],
        "about.totalReclaimed": [.en:"Total reclaimed", .ko:"총 회수한 용량", .ja:"回収した合計容量", .zhHans:"已回收总量", .zhHant:"已回收總量", .th:"กู้คืนแล้วทั้งหมด", .vi:"Tổng đã thu hồi", .it:"Totale recuperato", .fr:"Total récupéré", .es:"Total recuperado", .pt:"Total recuperado", .hr:"Ukupno vraćeno"],
        "about.license": [.en:"License", .ko:"저작권", .ja:"ライセンス", .zhHans:"许可证", .zhHant:"授權", .th:"สัญญาอนุญาต", .vi:"Giấy phép", .it:"Licenza", .fr:"Licence", .es:"Licencia", .pt:"Licença", .hr:"Licenca"],
        "about.author": [.en:"Author", .ko:"제작자", .ja:"制作者", .zhHans:"作者", .zhHant:"作者", .th:"ผู้สร้าง", .vi:"Tác giả", .it:"Autore", .fr:"Auteur", .es:"Autor", .pt:"Autor", .hr:"Autor"],
    ]
}
