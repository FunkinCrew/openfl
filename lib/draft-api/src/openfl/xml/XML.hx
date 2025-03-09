package openfl.xml;

import openfl.Lib;
import openfl.utils.Object;

abstract XML(Object) {
    
    public function new(value:Object) {
        Lib.notImplemented("XML.new");
    }

    public function toString():String {
        Lib.notImplemented("XML.toString");
        return "";
    }

    public function toXMLString():String {
        Lib.notImplemented("XML.toXMLString");
        return "";
    }

    public function localName():Object {
        Lib.notImplemented("XML.localName");
        return null;
    }

    public function name():Object {
        Lib.notImplemented("XML.name");
        return null;
    }

    public function namespace(prefix:String = null):Dynamic {
        Lib.notImplemented("XML.namespace");
        return null;
    }

    public function namespaceDeclarations():Array<Dynamic> {
        Lib.notImplemented("XML.namespaceDeclarations");
        return [];
    }

    public function attributes():XMLList {
        Lib.notImplemented("XML.attributes");
        return null;
    }

    public function attribute(attributeName:Dynamic):XMLList {
        Lib.notImplemented("XML.attribute");
        return null;
    }

    public function children():XMLList {
        Lib.notImplemented("XML.children");
        return null;
    }

    public function child(propertyName:Object):XMLList {
        Lib.notImplemented("XML.child");
        return null;
    }

    public function childIndex():Int {
        Lib.notImplemented("XML.childIndex");
        return -1;
    }

    public function comments():XMLList {
        Lib.notImplemented("XML.comments");
        return null;
    }

    public function contains(value:XML):Bool {
        Lib.notImplemented("XML.contains");
        return false;
    }

    public function copy():XML {
        Lib.notImplemented("XML.copy");
        return this;
    }

    public function descendants(name:Object = "*"):XMLList {
        Lib.notImplemented("XML.descendants");
        return null;
    }

    public function elements(name:Object = "*"):XMLList {
        Lib.notImplemented("XML.elements");
        return null;
    }

    public function hasComplexContent():Bool {
        Lib.notImplemented("XML.hasComplexContent");
        return false;
    }

    public function hasSimpleContent():Bool {
        Lib.notImplemented("XML.hasSimpleContent");
        return false;
    }

    public function inScopeNamespaces():Array<Dynamic> {
        Lib.notImplemented("XML.inScopeNamespaces");
        return [];
    }

    public function insertChildAfter(child1:Object, child2:Object):Dynamic {
        Lib.notImplemented("XML.insertChildAfter");
        return null;
    }

    public function insertChildBefore(child1:Object, child2:Object):Dynamic {
        Lib.notImplemented("XML.insertChildBefore");
        return null;
    }

    public function length():Int {
        Lib.notImplemented("XML.length");
        return 1;
    }

    public function nodeKind():String {
        Lib.notImplemented("XML.nodeKind");
        return "";
    }

    public function normalize():XML {
        Lib.notImplemented("XML.normalize");
        return this;
    }

    public function parent():XML {
        Lib.notImplemented("XML.parent");
        return null;
    }

    public function prependChild(value:Object):XML {
        Lib.notImplemented("XML.prependChild");
        return this;
    }

    public function processingInstructions(name:String = "*"):XMLList {
        Lib.notImplemented("XML.processingInstructions");
        return null;
    }

    public function removeNamespace(ns:Namespace):XML {
        Lib.notImplemented("XML.removeNamespace");
        return this;
    }

    public function replace(propertyName:Object, value:XML):XML {
        Lib.notImplemented("XML.replace");
        return this;
    }

    public function setChildren(value:Object):XML {
        Lib.notImplemented("XML.setChildren");
        return this;
    }

    public function setLocalName(name:String):Void {
        Lib.notImplemented("XML.setLocalName");
    }

    public function setName(name:String):Void {
        Lib.notImplemented("XML.setName");
    }

    public function setNamespace(ns:Namespace):Void {
        Lib.notImplemented("XML.setNamespace");
    }

    public static function defaultSettings():Object {
        Lib.notImplemented("XML.defaultSettings");
        return {};
    }

    public static function setSettings(...rest:Array<Dynamic>):Void {
        Lib.notImplemented("XML.setSettings");
    }

    public static function settings():Object {
        Lib.notImplemented("XML.settings");
        return {};
    }

    public static var ignoreComments:Bool;
    public static var ignoreProcessingInstructions:Bool;
    public static var ignoreWhitespace:Bool;
    public static var prettyIndent:Int;
    public static var prettyPrinting:Bool;

    public function text():XMLList {
        Lib.notImplemented("XML.text");
        return null;
    }

    public function toJSON(k:String):Dynamic {
        Lib.notImplemented("XML.toJSON");
        return null;
    }

    public function valueOf():XML {
        Lib.notImplemented("XML.valueOf");
        return this;
    }
}

