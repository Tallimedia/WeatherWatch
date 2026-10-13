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

    function pageCount() as Number { return Config.showForecast() ? 5 : 4; }

    function next() as Void { _page = (_page + 1) % pageCount(); WatchUi.requestUpdate(); }
    function prev() as Void { _page = (_page + pageCount() - 1) % pageCount(); WatchUi.requestUpdate(); }

    // Page order, held as constants rather than rebuilt on each draw: pageAt
    // runs inside onUpdate. About is last either way. Forecast (4) is opt-in
    // (RESEARCH.md §27, Config.showForecast) and travels as a pair with Land
    // directly after it in both orderings — it's conceptually part of "the
    // Land story", not a sixth independent concept.
    hidden const LAND_ORDER = [0, 1, 2, 3];
    hidden const SEA_ORDER = [1, 2, 0, 3];
    hidden const LAND_ORDER_FC = [0, 4, 1, 2, 3];
    hidden const SEA_ORDER_FC = [1, 2, 0, 4, 3];

    //! Maps the carousel position to a page, honouring both order settings.
    hidden function pageAt(index as Number) as Number {
        var fc = Config.showForecast();
        var order = Config.seaFirst()
            ? (fc ? SEA_ORDER_FC : SEA_ORDER)
            : (fc ? LAND_ORDER_FC : LAND_ORDER);
        return order[index % order.size()];
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
        else if (which == 2) { Pages.drawBuoy(dc); }
        else if (which == 4) { Pages.drawForecast(dc); }
        else { Pages.drawAbout(dc); }
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
        Api.refreshNow();
        WatchUi.requestUpdate();
        return true;
    }
}
