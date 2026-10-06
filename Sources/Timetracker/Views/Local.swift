import SwiftUI

/// Drop-in for `@State`. The macOS 26 SDK turned `@State` into a macro whose plugin ships only with Xcode;
/// Command Line Tools can still use the underlying `State` wrapper type.
@propertyWrapper struct Local<Value>: DynamicProperty {
    private var s: State<Value>
    init(wrappedValue: Value) { s = State(wrappedValue: wrappedValue) }
    var wrappedValue: Value { get { s.wrappedValue } nonmutating set { s.wrappedValue = newValue } }
    var projectedValue: Binding<Value> { s.projectedValue }
}
