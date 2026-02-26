# Word-by-Word Streaming Animation Implementation

## Overview

This document describes the implementation of a word-by-word streaming animation feature that simulates a typing effect for AI responses. The animation displays text progressively after receiving the complete response from the API, creating a smooth streaming-like experience.

## Key Concept

Instead of showing the full response immediately, we:
1. Receive the complete response from the API
2. Split the text into words (treating citations as single units)
3. Animate the display word-by-word at a controlled speed
4. Add the complete message to the conversation after animation completes

## Architecture

### ViewModel Changes

#### New State Variables

```swift
@Published var animatedResponseText: String = ""      // Currently displayed text during animation
@Published var isAnimatingResponse: Bool = false       // Animation state flag
private var animationTask: Task<Void, Never>?          // Task reference for cancellation
private var pendingMessageData: (content: String, sources: [Source], followUpQuestions: [String])?  // Message data to save after animation
```

#### Core Functions

1. **`splitIntoWords(_ text: String) -> [String]`**
   - Splits text into words for animation
   - Treats citations like `[1]`, `[2]` as single units
   - Handles consecutive citations like `[1][2][3]`
   - Preserves whitespace and formatting
   - Returns array of strings (words, citations, whitespace)

2. **`startWordByWordAnimation(fullText: String)`**
   - Cancels any existing animation
   - Splits text into words
   - Creates an async Task to animate word-by-word
   - Updates `animatedResponseText` incrementally
   - Calls `finishAnimation()` when complete

3. **`stopAnimation()`**
   - Cancels the animation task
   - Shows full text immediately
   - Calls `finishAnimation()` to save message

4. **`finishAnimation()`**
   - Saves message to Core Data
   - Adds message to messages array
   - Clears animation state
   - Triggers follow-up suggestions and related topics

## Implementation Steps

### Step 1: Add State Variables to ViewModel

```swift
@Published var animatedResponseText: String = ""
@Published var isAnimatingResponse: Bool = false
private var animationTask: Task<Void, Never>?
private var pendingMessageData: (content: String, sources: [Source], followUpQuestions: [String])?
```

### Step 2: Implement Word Splitting Function

The word splitting function must:
- Handle regular words
- Treat citations `[1]`, `[2]` as single units
- Handle consecutive citations `[1][2][3]`
- Preserve whitespace and newlines
- Combine consecutive whitespace to avoid too many animation steps

```swift
private func splitIntoWords(_ text: String) -> [String] {
    var words: [String] = []
    var currentWord = ""
    var i = text.startIndex
    
    while i < text.endIndex {
        let char = text[i]
        
        // Handle citations [1], [2], etc.
        if char == "[" {
            if !currentWord.isEmpty {
                words.append(currentWord)
                currentWord = ""
            }
            
            var citation = "["
            i = text.index(after: i)
            while i < text.endIndex && text[i] != "]" {
                citation.append(text[i])
                i = text.index(after: i)
            }
            
            if i < text.endIndex {
                citation.append(text[i])
                words.append(citation)
                i = text.index(after: i)
                
                // Handle consecutive citations [1][2][3]
                while i < text.endIndex && text[i] == "[" {
                    var nextCitation = "["
                    i = text.index(after: i)
                    while i < text.endIndex && text[i] != "]" {
                        nextCitation.append(text[i])
                        i = text.index(after: i)
                    }
                    if i < text.endIndex {
                        nextCitation.append(text[i])
                        words.append(nextCitation)
                        i = text.index(after: i)
                    } else {
                        break
                    }
                }
            } else {
                currentWord = citation
            }
        } else if char.isWhitespace || char.isNewline {
            if !currentWord.isEmpty {
                words.append(currentWord)
                currentWord = ""
            }
            // Combine consecutive whitespace
            if words.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                words[words.count - 1] += String(char)
            } else {
                words.append(String(char))
            }
            i = text.index(after: i)
        } else {
            currentWord.append(char)
            i = text.index(after: i)
        }
    }
    
    if !currentWord.isEmpty {
        words.append(currentWord)
    }
    
    return words
}
```

### Step 3: Implement Animation Function

```swift
private func startWordByWordAnimation(fullText: String) {
    // Cancel any existing animation
    stopAnimation()
    
    let words = splitIntoWords(fullText)
    guard !words.isEmpty else {
        finishAnimation()
        return
    }
    
    isAnimatingResponse = true
    animatedResponseText = ""
    
    // Create animation task
    animationTask = Task { @MainActor in
        for word in words {
            if Task.isCancelled {
                break
            }
            
            // Append word to animated text
            animatedResponseText += word
            
            // Wait before next word (40ms for words, 10ms for whitespace)
            let delay: UInt64 = word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
                ? 10_000_000  // 10ms for whitespace
                : 40_000_000  // 40ms for words
            
            try? await Task.sleep(nanoseconds: delay)
        }
        
        // Animation complete
        if !Task.isCancelled {
            finishAnimation()
        }
    }
}
```

### Step 4: Implement Stop and Finish Functions

```swift
private func stopAnimation() {
    animationTask?.cancel()
    animationTask = nil
    
    if isAnimatingResponse {
        // Show full text immediately
        animatedResponseText = streamingResponse
        finishAnimation()
    }
}

private func finishAnimation() {
    guard let messageData = pendingMessageData,
          let conversation = conversation else {
        isAnimatingResponse = false
        animatedResponseText = ""
        streamingResponse = ""
        pendingMessageData = nil
        return
    }
    
    // Save message to Core Data
    let assistantMessage = persistence.addMessage(
        to: conversation,
        content: messageData.content,
        role: "assistant",
        sources: messageData.sources,
        followUpSuggestions: messageData.followUpQuestions
    )
    
    messages.append(assistantMessage)
    
    // Clear animation state
    isAnimatingResponse = false
    animatedResponseText = ""
    streamingResponse = ""
    pendingMessageData = nil
    
    // Trigger follow-up suggestions and related topics
    followUpSuggestions = messageData.followUpQuestions
    // ... generate related topics
}
```

### Step 5: Update Message Sending Logic

Modify your `sendMessage()` function to:
1. Stop any ongoing animation when a new message is sent
2. Store the full response and message data
3. Start animation instead of immediately adding to messages

```swift
func sendMessage() async {
    // Stop any ongoing animation
    stopAnimation()
    
    // ... existing message sending logic ...
    
    // After receiving response from API:
    streamingResponse = cleanResponse
    pendingMessageData = (content: cleanResponse, sources: resolvedSources, followUpQuestions: followUpQuestions)
    
    isLoading = false
    
    // Start word-by-word animation
    startWordByWordAnimation(fullText: cleanResponse)
}
```

### Step 6: Update UI to Display Animated Text

#### Create Animated Response View Component

```swift
struct AnimatedResponseView: View {
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Use your existing message display component
            ArticleTextView(
                text: text,
                sources: [], // No sources during animation
                onSourceTap: { _ in }
            )
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }
}
```

#### Update Messages List

```swift
@ViewBuilder
private var messagesList: some View {
    ForEach(viewModel.messages, id: \.id) { message in
        MessageBubbleView(message: message, ...)
    }
    
    // Show animated response while animating
    if viewModel.isAnimatingResponse && !viewModel.animatedResponseText.isEmpty {
        AnimatedResponseView(text: viewModel.animatedResponseText)
            .id("animated-response")
    }
}
```

#### Add Auto-Scrolling

```swift
.onChange(of: viewModel.isAnimatingResponse) { animating in
    if animating && shouldAutoScrollToBottom {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                proxy.scrollTo("animated-response", anchor: .bottom)
            }
        }
    }
}
.onChange(of: viewModel.animatedResponseText) { _ in
    // Auto-scroll as text animates
    if viewModel.isAnimatingResponse && shouldAutoScrollToBottom {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo("animated-response", anchor: .bottom)
            }
        }
    }
}
```

## Key Considerations

### Animation Speed
- **40ms per word**: Good balance between responsiveness and visible animation
- **10ms for whitespace**: Faster for whitespace to avoid sluggish feeling
- Adjust these values based on your app's needs

### Citation Handling
- Citations like `[1]` must be treated as single units
- Consecutive citations `[1][2][3]` should each be separate units
- This preserves readability and makes citations feel cohesive

### Interruption Handling
- Always stop animation when a new message is sent
- Show full text immediately when interrupted
- Save message data even if interrupted

### State Management
- Clear animation state when starting new conversations
- Handle edge cases (empty responses, nil conversation, etc.)
- Ensure proper cleanup of tasks

### UI Updates
- Hide loading skeleton when animation starts
- Show animated view only when `isAnimatingResponse` is true
- Transition smoothly from animation to saved message

## Testing Checklist

- [ ] Animation starts immediately after receiving response
- [ ] Citations appear as single units
- [ ] Consecutive citations work correctly
- [ ] Animation stops when new message is sent
- [ ] Full text shows immediately when interrupted
- [ ] Message saves correctly after animation
- [ ] Auto-scrolling follows animated text
- [ ] Historical messages don't animate
- [ ] Edge cases handled (empty response, etc.)

## Performance Notes

- Animation uses `Task.sleep()` which is efficient
- Word splitting is done once per response
- No heavy computation during animation
- Cancellation is handled properly to avoid memory leaks

## Customization Options

### Adjust Animation Speed
```swift
let delay: UInt64 = word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
    ? 10_000_000  // Change this for whitespace speed
    : 40_000_000  // Change this for word speed
```

### Add Typing Indicator
You can add a blinking cursor or typing indicator during animation:
```swift
if viewModel.isAnimatingResponse {
    // Show typing indicator
    Text("|")
        .opacity(blinking ? 1.0 : 0.3)
        .animation(.easeInOut(duration: 0.5).repeatForever(), value: blinking)
}
```

### Pause on User Interaction
You can pause animation when user scrolls or interacts:
```swift
.onScrollGesture {
    if viewModel.isAnimatingResponse {
        viewModel.stopAnimation()
    }
}
```

## Migration Notes

When implementing in a new project:

1. **Adapt word splitting** to your citation format (if different)
2. **Adjust animation speeds** to match your app's feel
3. **Update UI components** to match your design system
4. **Handle your specific message model** (Core Data, Realm, etc.)
5. **Integrate with your API response structure**

## Example Flow

1. User sends message → `sendMessage()` called
2. API returns full response → Response stored in `streamingResponse`
3. Animation starts → `startWordByWordAnimation()` called
4. Words appear progressively → `animatedResponseText` updates
5. Animation completes → `finishAnimation()` called
6. Message saved → Added to `messages` array
7. UI updates → Animated view disappears, saved message appears

## Troubleshooting

### Animation doesn't start
- Check that `isAnimatingResponse` is set to `true`
- Verify `splitIntoWords()` returns non-empty array
- Ensure Task is created on `@MainActor`

### Animation too fast/slow
- Adjust delay values in `startWordByWordAnimation()`
- Test with different speeds (30ms, 50ms, etc.)

### Citations broken
- Verify citation regex/parsing in `splitIntoWords()`
- Check that citations are preserved as single units

### Memory issues
- Ensure `animationTask` is properly cancelled
- Check for retain cycles in Task closures

## Conclusion

This implementation provides a smooth, professional word-by-word animation effect that enhances the user experience by making AI responses feel more dynamic and engaging. The key is proper state management, efficient word splitting, and smooth UI transitions.
