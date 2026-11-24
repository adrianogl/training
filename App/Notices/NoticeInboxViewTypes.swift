enum NoticeTone {
    case neutral, danger, record, race
}

struct NoticeIcon {
    let linkPrefix: String
    let symbol: String
    let tone: NoticeTone
}
