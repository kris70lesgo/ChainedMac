import Carbon
import Foundation

final class GlobalHotKeys {
    private let actionHandler: (UInt32) -> Void
    private var eventHandler: EventHandlerRef?
    private var registrations: [EventHotKeyRef] = []
    private(set) var registeredIdentifiers: Set<UInt32> = []

    init(actionHandler: @escaping (UInt32) -> Void) {
        self.actionHandler = actionHandler
        install()
    }

    deinit {
        registrations.forEach { UnregisterEventHotKey($0) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    fileprivate func deliver(_ identifier: UInt32) {
        actionHandler(identifier)
    }

    private func install() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            chainYourMacHotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        guard installStatus == noErr else { return }

        let shift = UInt32(shiftKey)
        let restoreModifiers = UInt32(controlKey | optionKey)
        register(keyCode: UInt32(kVK_LeftArrow), modifiers: shift, identifier: 1)
        register(keyCode: UInt32(kVK_RightArrow), modifiers: shift, identifier: 2)
        register(keyCode: UInt32(kVK_ANSI_R), modifiers: restoreModifiers, identifier: 3)
    }

    private func register(keyCode: UInt32, modifiers: UInt32, identifier: UInt32) {
        var reference: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: 0x43594D43, id: identifier)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        if status == noErr, let reference {
            registrations.append(reference)
            registeredIdentifiers.insert(identifier)
        }
    }
}

private func chainYourMacHotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else { return noErr }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }

    let controller = Unmanaged<GlobalHotKeys>.fromOpaque(userData).takeUnretainedValue()
    let identifier = hotKeyID.id
    DispatchQueue.main.async { [weak controller] in
        controller?.deliver(identifier)
    }
    return noErr
}
