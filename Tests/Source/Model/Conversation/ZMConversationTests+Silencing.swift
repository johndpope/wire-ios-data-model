//
// Wire
// Copyright (C) 2018 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//

import XCTest
@testable import WireDataModel

class ZMConversationTests_Silencing: ZMConversationTestsBase {
    
    func testThatSilencingUpdatesProperties() {
        // given
        let timestamp = Date()
        let conversation = ZMConversation.insertNewObject(in: uiMOC)
        conversation.lastServerTimeStamp = timestamp
        
        // when
        conversation.isSilenced = true
        uiMOC.saveOrRollback()
        
        // then
        XCTAssertEqual(conversation.silencedChangedTimestamp, timestamp)
        XCTAssertTrue(conversation.modifiedKeys!.contains(ZMConversationSilencedChangedTimeStampKey))
    }
    
    // We still want to synchronize silenced changes even if nothing has happend in between
    func testThatSilencingUpdatesPropertiesWhenLastServerTimestampHasNotChanged() {
        // given
        let timestamp = Date()
        let conversation = ZMConversation.insertNewObject(in: uiMOC)
        conversation.lastServerTimeStamp = timestamp
        conversation.silencedChangedTimestamp = timestamp
        
        // when
        conversation.isSilenced = true
        uiMOC.saveOrRollback()
        
        // then
        XCTAssertEqual(conversation.silencedChangedTimestamp, timestamp)
        XCTAssertTrue(conversation.modifiedKeys!.contains(ZMConversationSilencedChangedTimeStampKey))
    }
    
    func testThatSilencingUpdatesPropertiesWhenPerformedOnSEContext() {
        syncMOC.performGroupedBlockAndWait {
            // given
            let timestamp = Date()
            let conversation = ZMConversation.insertNewObject(in: self.syncMOC)
            conversation.lastServerTimeStamp = timestamp
        
            // when
            conversation.updateSilenced(timestamp, synchronize: true)
            self.syncMOC.saveOrRollback()
            
            // then
            XCTAssertEqual(conversation.silencedChangedTimestamp, timestamp)
            XCTAssertTrue(conversation.modifiedKeys!.contains(ZMConversationSilencedChangedTimeStampKey))
        }

    }
    
    func testThatAppendingAMentionSelfMessageInAnArchivedSilencedConversationUnarchivesIt() {
        // GIVEN
        let conversation = ZMConversation.insertNewObject(in: self.uiMOC)
        conversation.conversationType = .group
        conversation.remoteIdentifier = UUID()
        
        let selfUser = ZMUser.selfUser(in: self.uiMOC)
        selfUser.remoteIdentifier = UUID()
        
        let otherUser = ZMUser.insertNewObject(in: self.uiMOC)
        otherUser.remoteIdentifier = UUID()
        
        conversation.mutableLastServerSyncedActiveParticipants.add(otherUser)
        
        conversation.isArchived = true
        conversation.isSilenced = true
        
        XCTAssertTrue(conversation.isArchived)
        XCTAssertTrue(conversation.isSilenced)
        
        // WHEN
        
        let mention = Mention(range: NSRange(location: 0, length: 9), user: selfUser)
        let text = ZMText.text(with: "@selfUser", mentions: [mention], linkPreviews: [])
        let message = ZMGenericMessage.message(content: text, nonce: UUID())
        
        let dataString = message.data()!.base64EncodedString()
        
        let payload = self.payloadForMessage(in: conversation, type: EventConversationAddClientMessage, data: dataString)!
        
        let event = ZMUpdateEvent.eventFromEventStreamPayload(payload, uuid: UUID())
        
        // when
        self.performPretendingUiMocIsSyncMoc {
            XCTAssertNotNil(ZMClientMessage.messageUpdateResult(from: event, in: self.uiMOC, prefetchResult: nil).message)
        }
        
        // THEN
        XCTAssertFalse(conversation.isArchived)
        XCTAssertTrue(conversation.isSilenced)
    }
    
}

