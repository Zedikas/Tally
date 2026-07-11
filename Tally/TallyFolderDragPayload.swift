import Foundation

extension TallyFolder {
    /// Lets a folder-header drop handler decode another dragged folder even when
    /// its local `folder` value shadows the view's payload helper method.
    /// `moveFolder` resolves the real stored record by this decoded identifier.
    func callAsFunction(from payload: String) -> TallyFolder? {
        guard payload.hasPrefix("folder:"),
              let id = UUID(uuidString: String(payload.dropFirst("folder:".count))) else {
            return nil
        }
        return TallyFolder(id: id, name: "Dragged Folder")
    }
}
