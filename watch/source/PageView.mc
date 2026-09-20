import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

//! One view that renders whichever page is active.
//!
//! A single view with an index, rather than three pushed views: it keeps the
//! memory footprint flat and makes page order a one-line change (RESEARCH.md
//! §17) instead of a navigation-stack rewrite.
class PageView extends WatchUi.View {

    hidden var _page as Number = 0;

    function initialize() {
        View.initialize();
        _page = Config.seaFirst() ? 1 : 0;
    }

    function pageCount() as Number { return 3; }

    function next() as Void { _page = (_page + 1) % pageCount(); WatchUi.requestUpdate(); }
    function prev() as Void { _page = (_page + pageCount() - 1) % pageCount(); WatchUi.requestUpdate(); }

    //! Maps the carousel position to a page, honouring the order setting.
    hidden function pageAt(index as Number) as Number {
        // Land order: Land, Sea, Buoy.  Sea order: Sea, Buoy, Land.
        if (Config.seaFirst()) {
            var seaOrder = [1, 2, 0];
            return seaOrder[index % 3];
        }
        return index % 3;
    }

    function onShow() as Void {
        Api.refreshAll();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.INK, Theme.BG);
        dc.clear();
        var which = pageAt(_page);
        if (which == 0) { Pages.drawLand(dc); }
        else if (which == 1) { Pages.drawSea(dc); }
        else { Pages.drawBuoy(dc); }
        Pages.drawPager(dc, _page, pageCount());
    }
}

//! Swipe up/down and the up/down buttons move between pages.
class PageDelegate extends WatchUi.BehaviorDelegate {
    hidden var _view as PageView;

    function initialize(view as PageView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onNextPage() as Boolean { _view.next(); return true; }
    function onPreviousPage() as Boolean { _view.prev(); return true; }

    function onSelect() as Boolean {
        Api.refreshAll();
        WatchUi.requestUpdate();
        return true;
    }
}
