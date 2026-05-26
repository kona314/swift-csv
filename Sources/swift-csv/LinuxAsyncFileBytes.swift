#if os(Linux)
import Foundation
import Glibc

struct LinuxAsyncFileBytes: AsyncSequence {
    typealias Element = UInt8

    let fd: Int32
    let bufferSize: Int

    struct Iterator: AsyncIteratorProtocol {
        let fd: Int32
        let bufferSize: Int
        var buffer: [UInt8] = []
        var index: Int = 0
        var didClose = false

        mutating func next() async throws -> UInt8? {
            if index < buffer.count {
                //return unconsumed buffer bytes if the exist
                let b = buffer[index]
                index += 1
                return b
            }

            guard !didClose else {
                return nil
            }

            //if there are no buffered bytes, read the next batch and return first
            buffer = [UInt8](repeating: 0, count: bufferSize)
            let count = read(fd, &buffer, bufferSize)

            if count > 0 {
                buffer.removeLast(buffer.count - count)
                index = 1
                return buffer[0]
            } else if count == 0 {
                closeIfNeeded()
                return nil //eof
            } else {
                closeIfNeeded()
                throw POSIXError(POSIXError.Code(rawValue: errno) ?? .EIO)
            }
        }

        private mutating func closeIfNeeded() {
            guard !didClose else { return }
            close(fd)
            didClose = true
        }
    }

    func makeAsyncIterator() -> Iterator {
        Iterator(fd: fd, bufferSize: bufferSize)
    }
}

extension LinuxAsyncFileBytes {
    init(url: URL, bufferSize: Int) throws {
        precondition(url.isFileURL, "URL must be a file:// URL")

        let path = url.path

        let fd = open(path, O_RDONLY)
        guard fd >= 0 else { 
            throw POSIXError(POSIXError.Code(rawValue: errno) ?? .EIO)
        }

        self.fd = fd
        self.bufferSize = bufferSize
    }
}
#endif 