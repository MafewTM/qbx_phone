var MessagesSearchActive = false;
var OpenedChatPicture = null;
var ExtraButtonsOpen = false;

$(document).ready(function(){
    $("#messages-search-input").on("keyup", function() {
        var value = $(this).val().toLowerCase();
        $(".messages-chats .messages-chat").filter(function() {
          $(this).toggle($(this).text().toLowerCase().indexOf(value) > -1);
        });
    });
});

$(document).on('click', '#messages-search-chats', function(e){
    e.preventDefault();

    if ($("#messages-search-input").css('display') == "none") {
        $("#messages-search-input").fadeIn(150);
        MessagesSearchActive = true;
    } else {
        $("#messages-search-input").fadeOut(150);
        MessagesSearchActive = false;
    }
});

$(document).on('click', '.messages-chat', function(e){
    e.preventDefault();

    var ChatId = $(this).attr('id');
    var ChatData = $("#"+ChatId).data('chatdata');

    QB.Phone.Functions.SetupChatMessages(ChatData);

    $.post('https://qbx_phone/ClearAlerts', JSON.stringify({
        number: ChatData.number
    }));

    if (MessagesSearchActive) {
        $("#messages-search-input").fadeOut(150);
    }

    $(".messages-openedchat").css({"display":"block"});
    $(".messages-openedchat").animate({
        left: 0+"vh"
    },200);

    $(".messages-chats").animate({
        left: 30+"vh"
    },200, function(){
        $(".messages-chats").css({"display":"none"});
    });

    $('.messages-openedchat-messages').animate({scrollTop: 9999}, 150);

    if (OpenedChatPicture == null) {
        OpenedChatPicture = "./img/default.png";
        if (ChatData.picture != null || ChatData.picture != undefined || ChatData.picture != "default") {
            OpenedChatPicture = ChatData.picture
        }
        $(".messages-openedchat-picture").css({"background-image":"url("+OpenedChatPicture+")"});
    }
});

$(document).on('click', '#messages-openedchat-back', function(e){
    e.preventDefault();
    $.post('https://qbx_phone/GetMessagesChats', JSON.stringify({}), function(chats){
        QB.Phone.Functions.LoadMessagesChats(chats);
    });
    OpenedChatData.number = null;
    $(".messages-chats").css({"display":"block"});
    $(".messages-chats").animate({
        left: 0+"vh"
    }, 200);
    $(".messages-openedchat").animate({
        left: -30+"vh"
    }, 200, function(){
        $(".messages-openedchat").css({"display":"none"});
    });
    OpenedChatPicture = null;
});

QB.Phone.Functions.GetLastMessage = function(messages) {
    var CurrentDate = new Date();
    var CurrentMonth = CurrentDate.getMonth();
    var CurrentDOM = CurrentDate.getDate();
    var CurrentYear = CurrentDate.getFullYear();
    var LastMessageData = {
        time: "00:00",
        message: "nothing"
    }

    $.each(messages[messages.length - 1], function(i, msg){
        var msgData = msg[msg.length - 1];
        LastMessageData.time = msgData.time
        LastMessageData.message = DOMPurify.sanitize(msgData.message , {
            ALLOWED_TAGS: [],
            ALLOWED_ATTR: []
        });
        if(LastMessageData.message == '') 'Hmm, I shouldn\'t be able to do this...'
    });

    return LastMessageData
}

GetCurrentDateKey = function() {
    var CurrentDate = new Date();
    var CurrentMonth = CurrentDate.getMonth();
    var CurrentDOM = CurrentDate.getDate();
    var CurrentYear = CurrentDate.getFullYear();
    var CurDate = ""+CurrentDOM+"-"+CurrentMonth+"-"+CurrentYear+"";

    return CurDate;
}

QB.Phone.Functions.LoadMessagesChats = function(chats) {
    $(".messages-chats").html("");
    $.each(chats, function(i, chat){
        var profilepicture = "./img/default.png";
        if (chat.picture !== "default") {
            profilepicture = chat.picture
        }
        var LastMessage = QB.Phone.Functions.GetLastMessage(chat.messages);
        var ChatElement = '<div class="messages-chat" id="messages-chat-'+i+'"><div class="messages-chat-picture" style="background-image: url('+profilepicture+');"></div><div class="messages-chat-name"><p>'+chat.name+'</p></div><div class="messages-chat-lastmessage"><p>'+LastMessage.message+'</p></div> <div class="messages-chat-lastmessagetime"><p>'+LastMessage.time+'</p></div><div class="messages-chat-unreadmessages unread-chat-id-'+i+'">1</div></div>';

        $(".messages-chats").append(ChatElement);
        $("#messages-chat-"+i).data('chatdata', chat);

        if (chat.Unread > 0 && chat.Unread !== undefined && chat.Unread !== null) {
            $(".unread-chat-id-"+i).html(chat.Unread);
            $(".unread-chat-id-"+i).css({"display":"block"});
        } else {
            $(".unread-chat-id-"+i).css({"display":"none"});
        }
    });
}

QB.Phone.Functions.ReloadMessagesAlerts = function(chats) {
    $.each(chats, function(i, chat){
        if (chat.Unread > 0 && chat.Unread !== undefined && chat.Unread !== null) {
            $(".unread-chat-id-"+i).html(chat.Unread);
            $(".unread-chat-id-"+i).css({"display":"block"});
        } else {
            $(".unread-chat-id-"+i).css({"display":"none"});
        }
    });
}

const monthNames = ["January", "February", "March", "April", "May", "June", "JulY", "August", "September", "October", "November", "December"];

FormatChatDate = function(date) {
    var TestDate = date.split("-");
    var NewDate = new Date((parseInt(TestDate[1]) + 1)+"-"+TestDate[0]+"-"+TestDate[2]);

    var CurrentMonth = monthNames[NewDate.getMonth()];
    var CurrentDOM = NewDate.getDate();
    var CurrentYear = NewDate.getFullYear();
    var CurDateee = CurrentDOM + "-" + NewDate.getMonth() + "-" + CurrentYear;
    var ChatDate = CurrentDOM + " " + CurrentMonth + " " + CurrentYear;
    var CurrentDate = GetCurrentDateKey();

    var ReturnedValue = ChatDate;
    if (CurrentDate == CurDateee) {
        ReturnedValue = "Today";
    }

    return ReturnedValue;
}

FormatMessageTime = function() {
    var NewDate = new Date();
    var NewHour = NewDate.getHours();
    var NewMinute = NewDate.getMinutes();
    var Minutessss = NewMinute;
    var Hourssssss = NewHour;
    if (NewMinute < 10) {
        Minutessss = "0" + NewMinute;
    }
    if (NewHour < 10) {
        Hourssssss = "0" + NewHour;
    }
    var MessageTime = Hourssssss + ":" + Minutessss
    return MessageTime;
}

$(document).on('click', '#messages-openedchat-send', function(e){
    e.preventDefault();

    var Message = $("#messages-openedchat-message").val();

    if (Message !== null && Message !== undefined && Message !== "") {
        $.post('https://qbx_phone/SendMessage', JSON.stringify({
            ChatNumber: OpenedChatData.number,
            ChatDate: GetCurrentDateKey(),
            ChatMessage: Message,
            ChatTime: FormatMessageTime(),
            ChatType: "message",
        }));
        $("#messages-openedchat-message").val("");
        $("div.emojionearea-editor").data("emojioneArea").setText('');
    } else {
        QB.Phone.Notifications.Add("fas fa-comment", "Messages", "You can't send a empty message!", "#25D366", 1750);
    }
});

$(document).on('keypress', function (e) {
    if (OpenedChatData.number !== null) {
        if(e.which === 13){
            var Message = $("#messages-openedchat-message").val();

            if (Message !== null && Message !== undefined && Message !== "") {
                var clean = DOMPurify.sanitize(Message , {
                    ALLOWED_TAGS: [],
                    ALLOWED_ATTR: []
                });
                if (clean == '') clean = 'Hmm, I shouldn\'t be able to do this...'
                $.post('https://qbx_phone/SendMessage', JSON.stringify({
                    ChatNumber: OpenedChatData.number,
                    ChatDate: GetCurrentDateKey(),
                    ChatMessage: clean,
                    ChatTime: FormatMessageTime(),
                    ChatType: "message",
                }));
                $("#messages-openedchat-message").val("");
            } else {
                QB.Phone.Notifications.Add("fas fa-comment", "Messages", "You can't send a empty message!", "#25D366", 1750);
            }
        }
    }
});

$(document).on('click', '#send-location', function(e){
    e.preventDefault();

    $.post('https://qbx_phone/SendMessage', JSON.stringify({
        ChatNumber: OpenedChatData.number,
        ChatDate: GetCurrentDateKey(),
        ChatMessage: "Shared location",
        ChatTime: FormatMessageTime(),
        ChatType: "location",
    }));
});

$(document).on('click', '#send-image', function(e){
    e.preventDefault();
    let ChatNumber2 = OpenedChatData.number;
    $.post('https://qbx_phone/TakePhoto', JSON.stringify({}),function(url){
        if(url){
        $.post('https://qbx_phone/SendMessage', JSON.stringify({
        ChatNumber: ChatNumber2,
        ChatDate: GetCurrentDateKey(),
        ChatMessage: "Photo",
        ChatTime: FormatMessageTime(),
        ChatType: "picture",
        url : url
    }))}})
    QB.Phone.Functions.Close();
});

QB.Phone.Functions.SetupChatMessages = function(cData, NewChatData) {
    if (cData) {
        OpenedChatData.number = cData.number;

        if (OpenedChatPicture == null) {
            $.post('https://qbx_phone/GetProfilePicture', JSON.stringify({
                number: OpenedChatData.number,
            }), function(picture){
                OpenedChatPicture = "./img/default.png";
                if (picture != "default" && picture != null) {
                    OpenedChatPicture = picture
                }
                $(".messages-openedchat-picture").css({"background-image":"url("+OpenedChatPicture+")"});
            });
        } else {
            $(".messages-openedchat-picture").css({"background-image":"url("+OpenedChatPicture+")"});
        }

        $(".messages-openedchat-name").html("<p>"+cData.name+"</p>");
        $(".messages-openedchat-messages").html("");

        $.each(cData.messages, function(i, chat){

            var ChatDate = FormatChatDate(chat.date);
            var ChatDiv = '<div class="messages-openedchat-messages-'+i+' unique-chat"><div class="messages-openedchat-date">'+ChatDate+'</div></div>';

            $(".messages-openedchat-messages").append(ChatDiv);

            $.each(cData.messages[i].messages, function(index, message){
                message.message = DOMPurify.sanitize(message.message , {
                    ALLOWED_TAGS: [],
                    ALLOWED_ATTR: []
                });
                if (message.message == '') message.message = 'Hmm, I shouldn\'t be able to do this...'
                var Sender = "me";
                if (message.sender !== QB.Phone.Data.PlayerData.citizenid) { Sender = "other"; }
                var MessageElement
                if (message.type == "message") {
                    MessageElement = '<div class="messages-openedchat-message messages-openedchat-message-'+Sender+'">'+message.message+'<div class="messages-openedchat-message-time">'+message.time+'</div></div><div class="clearfix"></div>'
                } else if (message.type == "location") {
                    MessageElement = '<div class="messages-openedchat-message messages-openedchat-message-'+Sender+' messages-shared-location" data-x="'+message.data.x+'" data-y="'+message.data.y+'"><span style="font-size: 1.2vh;"><i class="fas fa-map-marker-alt" style="font-size: 1vh;"></i> Location</span><div class="messages-openedchat-message-time">'+message.time+'</div></div><div class="clearfix"></div>'
                } else if (message.type == "picture") {
                    MessageElement = '<div class="messages-openedchat-message messages-openedchat-message-'+Sender+'" data-id='+OpenedChatData.number+'><img class="wppimage" src='+message.data.url +'  style=" border-radius:4px; width: 100%; position:relative; z-index: 1; right:1px;height: auto;"></div><div class="messages-openedchat-message-time">'+message.time+'</div></div><div class="clearfix"></div>'
                }
                $(".messages-openedchat-messages-"+i).append(MessageElement);
            });
        });
        $('.messages-openedchat-messages').animate({scrollTop: 9999}, 1);
    } else {
        OpenedChatData.number = NewChatData.number;
        if (OpenedChatPicture == null) {
            $.post('https://qbx_phone/GetProfilePicture', JSON.stringify({
                number: OpenedChatData.number,
            }), function(picture){
                OpenedChatPicture = "./img/default.png";
                if (picture != "default" && picture != null) {
                    OpenedChatPicture = picture
                }
                $(".messages-openedchat-picture").css({"background-image":"url("+OpenedChatPicture+")"});
            });
        }

        $(".messages-openedchat-name").html("<p>"+NewChatData.name+"</p>");
        $(".messages-openedchat-messages").html("");
        var NewDate = new Date();
        var NewDateMonth = NewDate.getMonth();
        var NewDateDOM = NewDate.getDate();
        var NewDateYear = NewDate.getFullYear();
        var DateString = ""+NewDateDOM+"-"+(NewDateMonth+1)+"-"+NewDateYear;
        var ChatDiv = '<div class="messages-openedchat-messages-'+DateString+' unique-chat"><div class="messages-openedchat-date">TODAY</div></div>';

        $(".messages-openedchat-messages").append(ChatDiv);
    }

    $('.messages-openedchat-messages').animate({scrollTop: 9999}, 1);
}

$(document).on('click', '.messages-shared-location', function(e){
    e.preventDefault();
    var messageCoords = {}
    messageCoords.x = $(this).data('x');
    messageCoords.y = $(this).data('y');

    $.post('https://qbx_phone/SharedLocation', JSON.stringify({
        coords: messageCoords,
    }))
});

$(document).on('click', '.wppimage', function(e){
    e.preventDefault();
    let source = $(this).attr('src')
   QB.Screen.popUp(source)
});

$(document).on('click', '#messages-openedchat-message-extras', function(e){
    e.preventDefault();

    if (!ExtraButtonsOpen) {
        $(".messages-extra-buttons").css({"display":"block"}).animate({
            left: 0+"vh"
        }, 250);
        ExtraButtonsOpen = true;
    } else {
        $(".messages-extra-buttons").animate({
            left: -10+"vh"
        }, 250, function(){
            $(".messages-extra-buttons").css({"display":"block"});
            ExtraButtonsOpen = false;
        });
    }
});
