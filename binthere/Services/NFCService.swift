import CoreNFC
import Foundation

@Observable
final class NFCService: NSObject {
    var scannedBinID: String?
    var writeSuccess = false
    var error: String?

    private var readSession: NFCNDEFReaderSession?
    private var writeSession: NFCNDEFReaderSession?
    private var pendingWritePayload: String?

    // MARK: - Read

    func startScanning() {
        guard NFCNDEFReaderSession.readingAvailable else {
            error = "NFC is not available on this device."
            return
        }

        scannedBinID = nil
        error = nil

        readSession = NFCNDEFReaderSession(delegate: self, queue: .main, invalidateAfterFirstRead: true)
        readSession?.alertMessage = "Hold your iPhone near a bin's NFC tag."
        readSession?.begin()
    }

    // MARK: - Write

    func writeTag(binID: String) {
        guard NFCNDEFReaderSession.readingAvailable else {
            error = "NFC is not available on this device."
            return
        }

        writeSuccess = false
        error = nil
        pendingWritePayload = binID

        writeSession = NFCNDEFReaderSession(delegate: self, queue: .main, invalidateAfterFirstRead: false)
        writeSession?.alertMessage = "Hold your iPhone near an empty NFC tag to write."
        writeSession?.begin()
    }

    // MARK: - Payload Helpers

    static func createPayload(binID: String) -> NFCNDEFPayload? {
        NFCNDEFPayload.wellKnownTypeTextPayload(string: binID, locale: Locale(identifier: "en"))
    }

    static func extractBinID(from payload: NFCNDEFPayload) -> String? {
        guard payload.typeNameFormat == .nfcWellKnown else { return nil }
        let (text, _) = payload.wellKnownTypeTextPayload()
        return text
    }
}

// MARK: - NFCNDEFReaderSessionDelegate

extension NFCService: NFCNDEFReaderSessionDelegate {

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: any Error) {
        let nfcError = error as? NFCReaderError
        // Don't report user cancellation as an error
        if nfcError?.code != .readerSessionInvalidationErrorUserCanceled {
            self.error = error.localizedDescription
        }
        readSession = nil
        writeSession = nil
        pendingWritePayload = nil
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Read mode — extract bin ID from first text record
        for message in messages {
            for record in message.records {
                if let binID = Self.extractBinID(from: record),
                   UUID(uuidString: binID) != nil {
                    scannedBinID = binID
                    return
                }
            }
        }
        error = "No bin data found on this NFC tag."
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [any NFCNDEFTag]) {
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No tag found.")
            return
        }

        session.connect(to: tag) { [weak self] connectError in
            guard let self else { return }
            if let connectError {
                session.invalidate(errorMessage: connectError.localizedDescription)
                return
            }

            if let writePayload = self.pendingWritePayload {
                // Write mode
                self.performWrite(session: session, tag: tag, binID: writePayload)
            } else {
                // Read mode with tag detection
                self.performRead(session: session, tag: tag)
            }
        }
    }

    private func performRead(session: NFCNDEFReaderSession, tag: any NFCNDEFTag) {
        tag.readNDEF { [weak self] message, readError in
            if let readError {
                session.invalidate(errorMessage: readError.localizedDescription)
                return
            }

            guard let message else {
                session.invalidate(errorMessage: "Tag is empty.")
                return
            }

            for record in message.records {
                if let binID = Self.extractBinID(from: record),
                   UUID(uuidString: binID) != nil {
                    self?.scannedBinID = binID
                    session.alertMessage = "Bin found!"
                    session.invalidate()
                    return
                }
            }
            session.invalidate(errorMessage: "No bin data on this tag.")
        }
    }

    private func performWrite(session: NFCNDEFReaderSession, tag: any NFCNDEFTag, binID: String) {
        tag.queryNDEFStatus { [weak self] status, _, queryError in
            if let queryError {
                session.invalidate(errorMessage: queryError.localizedDescription)
                return
            }

            guard status == .readWrite else {
                session.invalidate(errorMessage: "Tag is not writable.")
                return
            }

            guard let payload = Self.createPayload(binID: binID) else {
                session.invalidate(errorMessage: "Failed to create NFC data.")
                return
            }

            let message = NFCNDEFMessage(records: [payload])
            tag.writeNDEF(message) { writeError in
                if let writeError {
                    session.invalidate(errorMessage: writeError.localizedDescription)
                } else {
                    self?.writeSuccess = true
                    session.alertMessage = "Tag written successfully!"
                    session.invalidate()
                }
            }
        }
    }
}
