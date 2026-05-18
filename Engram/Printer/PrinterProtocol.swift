import CoreGraphics

protocol PrinterProtocol: AnyObject {
    func printRow(_ image: CGImage) async throws
}
