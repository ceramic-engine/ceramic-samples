package;

import ceramic.Color;
import ceramic.Quad;
import ceramic.Scene;
import ceramic.Timer;
import elements.Im;
import elements.Theme;

class MainScene extends Scene {

    var tint1:Color = 0x8C89CA;
    var tint2:Color = 0x6DC86E;
    var tint3:Color = 0xF18B66;

    var dangerousButtonPressed = false;
    var tintedWindowOpened = false;
    var anotherWindowOpened = false;
    var listWindowOpened = false;

    var showCountries = true;

    var selectedCity1:Int = -1;
    var selectedCity2:Int = -1;

    var listItems:Array<String> = [
        "Paris",
        "New York",
        "London",
        "Tokyo",
        "Beijing",
        "Rio de Janeiro",
        "Sydney",
        "Rome",
        "Istanbul",
        "Dubai",
        "Los Angeles",
        "Cape Town",
        "Toronto",
        "Mumbai",
        "Hong Kong",
        "Barcelona",
        "Berlin",
        "Amsterdam",
        "Bangkok"
    ];

    var extendedListItems:Array<Dynamic> = [
        { title: "Paris", subTitle: "France" },
        { title: "New York", subTitle: "United States" },
        { title: "London", subTitle: "United Kingdom" },
        { title: "Tokyo", subTitle: "Japan" },
        { title: "Beijing", subTitle: "China" },
        { title: "Rio de Janeiro", subTitle: "Brazil" },
        { title: "Sydney", subTitle: "Australia" },
        { title: "Rome", subTitle: "Italy" },
        { title: "Istanbul", subTitle: "Turkey" },
        { title: "Dubai", subTitle: "United Arab Emirates" },
        { title: "Los Angeles", subTitle: "United States" },
        { title: "Cape Town", subTitle: "South Africa" },
        { title: "Toronto", subTitle: "Canada" },
        { title: "Mumbai", subTitle: "India" },
        { title: "Hong Kong", subTitle: "China" },
        { title: "Barcelona", subTitle: "Spain" },
        { title: "Berlin", subTitle: "Germany" },
        { title: "Amsterdam", subTitle: "Netherlands" },
        { title: "Bangkok", subTitle: "Thailand" }
    ];

    override function preload() {

        // Add any asset you want to load here

        assets.add(Images.CERAMIC);

    }

    override function create() {

    }

    override function update(delta:Float) {

        // Tell Im to use our assets object
        Im.assets(assets);

        // First window
        Im.begin('Demo', 250);

        Im.text('Hello, world!');

        Im.slideFloat('Float', Im.float(), 0, 1);

        Im.space();

        Im.text('Look! This window has tabs:');

        Im.beginTabs(Im.string());

        var tintedWindowJustOpened = false;
        var anotherWindowJustOpened = false;
        var listWindowJustOpened = false;

        if (Im.tab('Tinted window')) {
            Im.editColor('Tint', Im.color(tint1));
            if (tintedWindowOpened) Im.disabled(true);
            if (Im.button('Open window')) {
                tintedWindowJustOpened = true;
                tintedWindowOpened = true;
            }
            Im.disabled(false);
        }

        if (Im.tab('Danger zone')) {
            Im.text('This is an example of critical action you are being warned about:');
            Im.margin();
            Im.background(0xFF0000);
            Im.textColor(Timer.now % 1.0 < 0.5 ? Color.BLACK : Color.WHITE);
            Im.text('Beware, DANGER ZONE!');
            Im.background();
            Im.textColor();
            Im.margin();
            Im.tint(0xFF0000);
            Im.background(Im.defaultTheme.windowBackgroundColor);
            if (dangerousButtonPressed) {
                Im.text('- BOOM -');
            }
            else if (Im.button('Press dangerous button')) {
                dangerousButtonPressed = true;
            }
            Im.tint();
            Im.background();
        }

        Im.endTabs();

        Im.separator();

        if (anotherWindowOpened) Im.disabled(true);
        if (Im.button('Click to open another window')) {
            anotherWindowOpened = true;
            anotherWindowJustOpened = true;
        }
        Im.disabled(false);

        if (listWindowOpened) Im.disabled(true);
        if (Im.button('Open window with list')) {
            listWindowOpened = true;
            listWindowJustOpened = true;
        }
        Im.disabled(false);

        Im.end();

        // Another window
        if (anotherWindowOpened) {
            Im.begin('Another window');
            if (anotherWindowJustOpened) {
                Im.position(screen.nativeWidth * 0.5, screen.nativeHeight * 0.4);
                Im.focus();
            }
            Im.closable(Im.bool(anotherWindowOpened));

            Im.beginTabs(Im.string());

            if (Im.tab('Images')) {

                Im.beginRow();
                Im.space();
                Im.image(Images.CERAMIC);
                Im.space();
                Im.endRow();

                Im.text('Ceramic Logo', CENTER);
            }

            Im.tint(tint2);
            if (Im.tab('Tinted tab')) {

                Im.text('Tabs can be tinted too!');
                Im.editColor('Tab tint', Im.color(tint2));

            }
            Im.tint();

            Im.endTabs();

            Im.end();
        }

        // Tinted window
        if (tintedWindowOpened) {
            Im.tint(tint1);
            Im.begin('Tinted window');
            if (tintedWindowJustOpened) {
                Im.position(screen.nativeWidth * 0.5, screen.nativeHeight * 0.5);
                Im.focus();
            }
            Im.closable(Im.bool(tintedWindowOpened));

            Im.text('This window is tinted. You can change the color from the "Tint window" tab in the Demo window!');

            Im.separator(0);

            Im.text('Also notice the cross at the top right of this window: it makes this window closable!');

            Im.end();
            Im.tint();
        }

        // List window
        if (listWindowOpened) {
            Im.tint(tint3);

            Im.begin('Lists', 250);
            Im.beginTabs(Im.string());
            if (listWindowJustOpened) {
                Im.focus();
            }
            Im.closable(Im.bool(listWindowOpened));

            if (Im.tab('Simple')) {

                Im.text('Here is a list of cities. You can drag them to sort them!');
                Im.list(250, Im.array(listItems), Im.int(selectedCity1), true);

                Im.text('Selected: ' + (selectedCity1 >= 0 ? listItems[selectedCity1] : 'none'));
            }

            if (Im.tab('Advanced')) {

                Im.text('Another more advanced list where items can be locked, duplicated or even trashed!');
                Im.check('Show countries', Im.bool(showCountries));
                var status = Im.list(showCountries, 250, Im.array(extendedListItems), Im.int(selectedCity2), true, true, true, true);
                if (status.duplicateItems.length > 0) {
                    extendedListItems = [].concat(extendedListItems);
                    for (item in status.duplicateItems) {
                        extendedListItems.insert(extendedListItems.indexOf(item) + 1, Reflect.copy(item));
                    }
                }

                Im.text('Selected: ' + (selectedCity2 >= 0 && selectedCity2 < extendedListItems.length ? extendedListItems[selectedCity2].title : 'none'));
            }

            Im.end();
            Im.tint();
        }

    }

}
